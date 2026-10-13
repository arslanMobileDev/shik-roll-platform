import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Customer, OrderStatus, Prisma } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { LoyaltyService } from '../loyalty/loyalty.service';
import {
  ACCOUNT_FLOW_TOKEN_TTL_SECONDS,
  BLOCKING_ORDER_STATUSES,
  DELETION_TOKEN_TYPE,
  DeletionReason,
  PHONE_RELEASE_WINDOW_DAYS,
} from './customers.config';
import { ConfirmDeletionDto } from './dto/confirm-deletion.dto';
import {
  ConfirmDeletionResponse,
  DeletionRequestResponse,
} from './entities/customer-deletion.entities';

/** The JWT payload of the one-shot account-flow tokens. */
interface AccountFlowTokenPayload {
  sub?: unknown;
  type?: unknown;
}

/**
 * Customer account lifecycle: self-service deletion (soft delete +
 * anonymization) and the phone freeze that follows it.
 *
 * A Customer row is never hard-deleted — orders and bonus_accounts reference it
 * with ON DELETE RESTRICT, and those rows are the financial history. Deletion
 * instead erases the personal fields and stamps deleted_at, parking the phone
 * in phone_pending_release for the restore window.
 */
@Injectable()
export class CustomersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly loyalty: LoyaltyService,
    private readonly jwt: JwtService,
  ) {}

  /**
   * Step 1 of deletion: mint a short-lived confirmation token and report what
   * the customer is about to lose. The bonus balance is read here only to warn
   * them — the amount actually burned is returned by confirmDeletion, because
   * this snapshot can go stale (cashback lands, another order commits).
   */
  async requestDeletion(customerId: string): Promise<DeletionRequestResponse> {
    const customer = await this.prisma.customer.findUnique({
      where: { id: customerId },
      select: { deletedAt: true },
    });
    if (!customer) {
      throw customerNotFound(customerId);
    }
    if (customer.deletedAt) {
      throw alreadyDeleted();
    }

    const [account, blockingOrders] = await Promise.all([
      this.prisma.bonusAccount.findUnique({
        where: { customerId },
        select: { balance: true },
      }),
      this.blockingOrders(customerId, this.prisma),
    ]);

    const deletionToken = await this.jwt.signAsync(
      { sub: customerId, type: DELETION_TOKEN_TYPE },
      { expiresIn: ACCOUNT_FLOW_TOKEN_TTL_SECONDS },
    );

    return {
      deletionToken,
      expiresInSeconds: ACCOUNT_FLOW_TOKEN_TTL_SECONDS,
      bonusBalance: account?.balance ?? 0,
      canDelete: blockingOrders === 0,
      ...(blockingOrders > 0
        ? { blockedReason: 'ACTIVE_ORDERS_EXIST' as const }
        : {}),
    };
  }

  /**
   * Step 2 of deletion, in one transaction: burn the bonus balance, then
   * anonymize the row and freeze the phone. Either both land or neither does —
   * an anonymized row holding bonuses would be the worst of both outcomes.
   */
  async confirmDeletion(
    customerId: string,
    dto: ConfirmDeletionDto,
  ): Promise<ConfirmDeletionResponse> {
    const payload = await this.verifyFlowToken(
      dto.deletionToken,
      DELETION_TOKEN_TYPE,
    );
    // The token names the account it was issued for; an access token for a
    // different customer must not be able to delete this one.
    if (payload.sub !== customerId) {
      throw new ForbiddenException({
        statusCode: 403,
        code: 'DELETION_TOKEN_MISMATCH',
        message: 'The deletion token was issued for another account',
      });
    }

    const expiredPoints = await this.prisma.$transaction(async (tx) => {
      const customer = await tx.customer.findUnique({
        where: { id: customerId },
        select: { phone: true, deletedAt: true },
      });
      if (!customer) {
        throw customerNotFound(customerId);
      }
      // Re-deleting is refused, not silently accepted: the caller is holding a
      // token for an account that is already gone.
      if (customer.deletedAt) {
        throw alreadyDeleted();
      }
      const blocking = await this.blockingOrders(customerId, tx);
      if (blocking > 0) {
        throw new ConflictException({
          statusCode: 409,
          code: 'ACTIVE_ORDERS_EXIST',
          message: `Cannot delete the account while ${blocking} order(s) are still in progress`,
        });
      }

      // Keyed by the deletion event, so a later delete/restore/delete cycle
      // expires the second balance too (see LedgerKeys.expireOnDelete).
      const burned = await this.loyalty.expireAllWithinTransaction(tx, {
        customerId,
        deletionId: randomUUID(),
      });

      await tx.customer.update({
        where: { id: customerId },
        data: {
          deletedAt: new Date(),
          // Server-side constant: the request body must never be able to write
          // free text into a row we are calling anonymized.
          deletedReason: DeletionReason.USER_REQUEST,
          phonePendingRelease: customer.phone,
          phone: null,
          name: null,
          email: null,
        },
      });

      return burned;
    });

    return { deleted: true, expiredBonusPoints: expiredPoints };
  }

  /**
   * The newest deleted account still holding this phone inside the freeze
   * window, if any. Used by the OTP login to offer a restore instead of
   * provisioning a second account on the same number.
   *
   * The window filter is also the correctness backstop when the release job is
   * off (DISABLE_QUEUES): a pending phone past its window is never restored.
   */
  async findFrozenByPhone(
    phone: string,
  ): Promise<{ id: string; deletedAt: Date } | null> {
    const frozen = await this.prisma.customer.findFirst({
      where: {
        phonePendingRelease: phone,
        deletedAt: { gt: freezeCutoff() },
      },
      orderBy: { deletedAt: 'desc' },
      select: { id: true, deletedAt: true },
    });
    // The `deletedAt > cutoff` filter above already excludes nulls; this is
    // just the narrowing TypeScript cannot infer from the where clause.
    if (!frozen?.deletedAt) {
      return null;
    }
    return { id: frozen.id, deletedAt: frozen.deletedAt };
  }

  /**
   * Returns the frozen phone to the account and lifts the tombstone. Bonus
   * history survives in the ledger, but the balance stays burned — restoring
   * an account does not restore the bonuses that expired with it.
   */
  async unfreeze(customerId: string): Promise<Customer> {
    try {
      return await this.prisma.$transaction(async (tx) => {
        const frozen = await tx.customer.findUnique({
          where: { id: customerId },
          select: { phonePendingRelease: true, deletedAt: true },
        });
        if (!frozen || !frozen.deletedAt) {
          throw new ConflictException({
            statusCode: 409,
            code: 'ACCOUNT_NOT_DELETED',
            message: 'This account is not deleted',
          });
        }
        if (!frozen.phonePendingRelease) {
          // The freeze window closed and the release job already erased the
          // number; there is nothing left to restore it to.
          throw new ConflictException({
            statusCode: 409,
            code: 'RESTORE_WINDOW_EXPIRED',
            message: 'The restore window for this account has expired',
          });
        }
        return tx.customer.update({
          where: { id: customerId },
          data: {
            phone: frozen.phonePendingRelease,
            phonePendingRelease: null,
            deletedAt: null,
            deletedReason: null,
          },
        });
      });
    } catch (error) {
      // Someone registered the freed number between the restore offer and its
      // confirmation — uq_customers_phone rejects the write.
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ConflictException({
          statusCode: 409,
          code: 'RESTORE_CONFLICT',
          message: 'This phone number was registered by someone else',
        });
      }
      throw error;
    }
  }

  private blockingOrders(
    customerId: string,
    client: Prisma.TransactionClient | PrismaService,
  ): Promise<number> {
    return client.order.count({
      where: {
        customerId,
        deletedAt: null,
        status: { in: [...BLOCKING_ORDER_STATUSES] as OrderStatus[] },
      },
    });
  }

  /**
   * Validates a one-shot account-flow token and returns its payload, or 401.
   * Neither 'delete' nor 'restore' passes the access-token type check in
   * JwtAuthGuard, so these can never be replayed as a session.
   */
  async verifyFlowToken(
    token: string,
    expectedType: string,
  ): Promise<{ sub: string }> {
    try {
      const payload = await this.jwt.verifyAsync<AccountFlowTokenPayload>(token);
      if (
        payload.type !== expectedType ||
        typeof payload.sub !== 'string' ||
        !payload.sub.trim()
      ) {
        throw new Error(`Unexpected token type: ${String(payload.type)}`);
      }
      return { sub: payload.sub };
    } catch {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'ACCOUNT_TOKEN_INVALID',
        message: 'Invalid or expired token',
      });
    }
  }
}

/** Start of the freeze window: deletions newer than this can still restore. */
export function freezeCutoff(now: Date = new Date()): Date {
  return new Date(now.getTime() - PHONE_RELEASE_WINDOW_DAYS * 24 * 60 * 60 * 1000);
}

function alreadyDeleted(): ConflictException {
  return new ConflictException({
    statusCode: 409,
    code: 'ACCOUNT_ALREADY_DELETED',
    message: 'This account is already deleted',
  });
}

function customerNotFound(customerId: string): NotFoundException {
  return new NotFoundException({
    statusCode: 404,
    code: 'CUSTOMER_NOT_FOUND',
    message: `Customer ${customerId} not found`,
  });
}
