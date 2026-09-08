import {
  ConflictException,
  Injectable,
  UnprocessableEntityException,
} from '@nestjs/common';
import {
  BonusAccount,
  BonusTransactionType,
  Prisma,
  PromotionCampaign,
  PromotionCampaignStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  bonusLimitPoints,
  cashbackPoints,
} from './domain/bonus-rules';
import {
  LoyaltyBalanceResponseDto,
  PromotionFeedResponseDto,
} from './entities/loyalty.entities';

/** Ledger idempotency keys (ADR-1614): one entry of each kind per order. */
export const LedgerKeys = {
  spend: (orderId: string) => `spend:${orderId}`,
  earn: (orderId: string) => `earn:${orderId}`,
  refund: (orderId: string) => `refund:${orderId}`,
} as const;

/** Bounded retries of the balance compare-and-set loop. */
const MAX_LEDGER_ATTEMPTS = 3;

interface LedgerEntryParams {
  customerId: string;
  orderId: string | null;
  type: BonusTransactionType;
  /** Signed points: EARN/REFUND > 0; SPEND/EXPIRE < 0. */
  points: number;
  idempotencyKey: string;
  createAccountIfMissing: boolean;
}

function isUniqueViolation(error: unknown): boolean {
  return (
    error instanceof Prisma.PrismaClientKnownRequestError &&
    error.code === 'P2002'
  );
}

/**
 * Loyalty bounded context (ADR-1614). BonusTransaction is the immutable
 * ledger; BonusAccount.balance is its atomically updated projection. Every
 * balance mutation is a compare-and-set on the exact read balance, so the
 * recorded balance_after always matches the applied delta, and the database
 * CHECK (balance >= 0) can never be violated by concurrent spends.
 */
@Injectable()
export class LoyaltyService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * GET /loyalty/balance: current balance, cashback rate and a page of the
   * ledger, newest first (created_at DESC, id DESC). The account is
   * auto-provisioned on first access with a zero balance.
   */
  async getBalance(
    customerId: string,
    page: number,
    pageSize: number,
  ): Promise<LoyaltyBalanceResponseDto> {
    const account = await this.prisma.bonusAccount.upsert({
      where: { customerId },
      update: {},
      create: { customerId },
    });

    const [transactions, total] = await this.prisma.$transaction([
      this.prisma.bonusTransaction.findMany({
        where: { accountId: account.id },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      this.prisma.bonusTransaction.count({ where: { accountId: account.id } }),
    ]);

    return {
      balance: account.balance,
      cashback_rate: account.cashbackRate.toNumber(),
      transactions: transactions.map((transaction) => ({
        id: transaction.id,
        type: transaction.type,
        points: transaction.points,
        balance_after: transaction.balanceAfter,
        order_id: transaction.orderId,
        created_at: transaction.createdAt.toISOString(),
        expires_at: transaction.expiresAt?.toISOString() ?? null,
      })),
      pagination: {
        page,
        page_size: pageSize,
        total,
        total_pages: Math.ceil(total / pageSize),
      },
    };
  }

  /**
   * GET /promotions/feed: ACTIVE campaigns of the brand whose window contains
   * now, ordered priority DESC, starts_at DESC (mobile app carousel).
   */
  async getPromotionFeed(brandId: string): Promise<PromotionFeedResponseDto> {
    const now = new Date();
    const campaigns = await this.prisma.promotionCampaign.findMany({
      where: {
        brandId,
        status: PromotionCampaignStatus.ACTIVE,
        startsAt: { lte: now },
        endsAt: { gt: now },
      },
      orderBy: [{ priority: 'desc' }, { startsAt: 'desc' }],
    });
    return { items: campaigns.map(toFeedItem) };
  }

  /**
   * Checkout pre-checks (ADR-1614): 422 BONUS_LIMIT_EXCEEDED when the request
   * exceeds 30% of the bonus base, 409 INSUFFICIENT_BONUS_BALANCE when the
   * balance cannot cover it. The balance is re-checked atomically inside the
   * order transaction (spendWithinTransaction), so a race can never spend
   * points that are no longer there.
   */
  async assertSpendAllowed(
    customerId: string,
    points: number,
    bonusBase: Prisma.Decimal,
  ): Promise<void> {
    const limit = bonusLimitPoints(bonusBase);
    if (points > limit) {
      throw new UnprocessableEntityException({
        statusCode: 422,
        code: 'BONUS_LIMIT_EXCEEDED',
        message: `Bonus points ${points} exceed the 30% limit of ${limit} for this order`,
      });
    }
    const account = await this.prisma.bonusAccount.findUnique({
      where: { customerId },
    });
    const balance = account?.balance ?? 0;
    if (points > balance) {
      throw new ConflictException({
        statusCode: 409,
        code: 'INSUFFICIENT_BONUS_BALANCE',
        message: `Bonus balance ${balance} cannot cover ${points} points`,
      });
    }
  }

  /**
   * Conditional balance decrement + SPEND ledger entry, executed inside the
   * order creation transaction so order, balance and ledger commit or roll
   * back together (ADR-1614). Ledger key: spend:{orderId}.
   */
  async spendWithinTransaction(
    tx: Prisma.TransactionClient,
    params: { customerId: string; orderId: string; points: number },
  ): Promise<void> {
    await this.applyLedgerEntry(tx, {
      customerId: params.customerId,
      orderId: params.orderId,
      type: BonusTransactionType.SPEND,
      points: -params.points,
      idempotencyKey: LedgerKeys.spend(params.orderId),
      createAccountIfMissing: false,
    });
  }

  /**
   * Cashback accrual on the internal transition to COMPLETED (projected to
   * the customer as DELIVERED): floor(payable_item_amount * rate / 100) on
   * the amount actually paid for items (after all discounts). Idempotent —
   * a repeated COMPLETED never changes the balance. Ledger key: earn:{orderId}.
   */
  async earnCashback(orderId: string): Promise<void> {
    const order = await this.prisma.order.findFirst({
      where: { id: orderId, deletedAt: null },
      select: { customerId: true, totalAmount: true },
    });
    if (!order?.customerId) {
      return;
    }
    const account = await this.prisma.bonusAccount.findUnique({
      where: { customerId: order.customerId },
    });
    const points = cashbackPoints(
      order.totalAmount,
      account?.cashbackRate ?? new Prisma.Decimal(0),
    );
    // Ledger rows are never zero (CHECK points <> 0): nothing to accrue.
    if (points <= 0) {
      return;
    }
    await this.runIdempotent((tx) =>
      this.applyLedgerEntry(tx, {
        customerId: order.customerId!,
        orderId,
        type: BonusTransactionType.EARN,
        points,
        idempotencyKey: LedgerKeys.earn(orderId),
        createAccountIfMissing: true,
      }),
    );
  }

  /**
   * Compensation for a cancelled/refunded order (ADR-1614): the points spent
   * at checkout return to the balance as a REFUND entry. Idempotent; a no-op
   * when the order never spent bonuses. Ledger key: refund:{orderId}.
   */
  async refundOnCancel(orderId: string): Promise<void> {
    const order = await this.prisma.order.findFirst({
      where: { id: orderId, deletedAt: null },
      select: { customerId: true },
    });
    if (!order?.customerId) {
      return;
    }
    const spend = await this.prisma.bonusTransaction.findUnique({
      where: { idempotencyKey: LedgerKeys.spend(orderId) },
    });
    if (!spend) {
      return;
    }
    await this.runIdempotent((tx) =>
      this.applyLedgerEntry(tx, {
        customerId: order.customerId!,
        orderId,
        type: BonusTransactionType.REFUND,
        points: -spend.points, // SPEND rows are negative; the refund restores them
        idempotencyKey: LedgerKeys.refund(orderId),
        createAccountIfMissing: true,
      }),
    );
  }

  /**
   * Runs a ledger mutation in one transaction. A concurrent application of
   * the same idempotency key aborts our transaction (rolling the balance
   * change back with it) and is treated as already applied — the winner's
   * commit carried both the balance and the ledger row.
   */
  private async runIdempotent(
    mutation: (tx: Prisma.TransactionClient) => Promise<void>,
  ): Promise<void> {
    try {
      await this.prisma.$transaction(mutation);
    } catch (error) {
      if (isUniqueViolation(error)) {
        return;
      }
      throw error;
    }
  }

  /**
   * Appends one ledger row and moves the balance projection atomically.
   * The balance update is a compare-and-set on the exact read value; on a
   * concurrent modification the loop re-reads and retries, so balance_after
   * is always the balance immediately after this entry. Negative outcomes
   * are rejected before the write (409 INSUFFICIENT_BONUS_BALANCE).
   */
  private async applyLedgerEntry(
    tx: Prisma.TransactionClient,
    params: LedgerEntryParams,
  ): Promise<void> {
    const existing = await tx.bonusTransaction.findUnique({
      where: { idempotencyKey: params.idempotencyKey },
      select: { id: true },
    });
    if (existing) {
      return;
    }

    for (let attempt = 0; attempt < MAX_LEDGER_ATTEMPTS; attempt++) {
      let account: BonusAccount | null = await tx.bonusAccount.findUnique({
        where: { customerId: params.customerId },
      });
      if (!account) {
        if (!params.createAccountIfMissing) {
          throw insufficientBalance(0, -params.points);
        }
        try {
          account = await tx.bonusAccount.create({
            data: { customerId: params.customerId },
          });
        } catch (error) {
          // Concurrent provisioning of the same account — re-read and retry.
          if (isUniqueViolation(error)) {
            continue;
          }
          throw error;
        }
      }

      const balanceAfter = account.balance + params.points;
      if (balanceAfter < 0) {
        throw insufficientBalance(account.balance, -params.points);
      }

      const updated = await tx.bonusAccount.updateMany({
        where: { id: account.id, balance: account.balance },
        data: { balance: balanceAfter },
      });
      if (updated.count === 0) {
        continue; // balance moved concurrently — re-read and retry
      }

      await tx.bonusTransaction.create({
        data: {
          accountId: account.id,
          orderId: params.orderId,
          type: params.type,
          points: params.points,
          balanceAfter,
          idempotencyKey: params.idempotencyKey,
        },
      });
      return;
    }

    throw new ConflictException({
      statusCode: 409,
      code: 'BONUS_BALANCE_CONFLICT',
      message: 'Bonus balance is being updated concurrently, retry the operation',
    });
  }
}

function insufficientBalance(balance: number, points: number): ConflictException {
  return new ConflictException({
    statusCode: 409,
    code: 'INSUFFICIENT_BONUS_BALANCE',
    message: `Bonus balance ${balance} cannot cover ${points} points`,
  });
}

function toFeedItem(campaign: PromotionCampaign) {
  return {
    id: campaign.id,
    title: campaign.title,
    description: campaign.description,
    banner_url: campaign.bannerUrl,
    action_url: campaign.actionUrl,
    starts_at: campaign.startsAt.toISOString(),
    ends_at: campaign.endsAt.toISOString(),
  };
}
