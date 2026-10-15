import { createHash, timingSafeEqual } from 'crypto';
import * as bcrypt from 'bcryptjs';
import { constantTimePinCheck } from '../tenant/pin-timing';
import {
  pinRateLimitConsume,
  pinRateLimitReset,
} from '../tenant/pin-rate-limit';
import {
  ConflictException,
  ForbiddenException,
  HttpException,
  Injectable,
  NotFoundException,
  Optional,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../prisma/prisma.service';
import { resolveLoginRow } from '../tenant/resolve-login-row';
import { ACTIVE_TENANT_FILTER, TenantContext } from '../tenant/tenant.types';
import {
  Courier,
  Order,
  OrderStatus,
  OrderType,
  PaymentMethod,
  Prisma,
} from '@prisma/client';
import { CourierPinAuthDto } from './dto/courier-auth.dto';
import { UpdateCourierOrderStatusDto } from './dto/update-courier-order-status.dto';
import { ReportCourierLocationDto } from './dto/report-courier-location.dto';
import { CourierHistoryQueryDto } from './dto/courier-history-query.dto';
import { DeleteCourierAccountDto } from './dto/delete-courier-account.dto';
import {
  COURIER_LOCATION_MAX_CLOCK_SKEW_MS,
  COURIER_LOCATION_MIN_INTERVAL_MS,
  COURIER_RESTORE_WINDOW_DAYS,
  COURIER_TOKEN_TTL_SECONDS,
  PIN_BCRYPT_ROUNDS,
} from './couriers.config';
import { AuthenticatedCourier, CourierTokenPayload } from './couriers.types';
import { CouriersEventsService } from './couriers-events.service';
import { KitchenEventsService } from '../kitchen/kitchen-events.service';
import { LoyaltyService } from '../loyalty/loyalty.service';

/** bcrypt hashes carry a version prefix ($2a$/$2b$/$2y$); anything else is a legacy plaintext row. */
function isBcryptHash(value: string): boolean {
  return /^\$2[aby]\$/.test(value);
}

@Injectable()
export class CouriersService {
  /** Last accepted location fix per courier (in-memory rate limiter). */
  private readonly lastLocationAt = new Map<string, number>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly events: CouriersEventsService,
    private readonly loyalty: LoyaltyService,
    // Optional so unit specs can construct the service without the kitchen
    // bounded context; always present in the wired app.
    @Optional() private readonly kitchenEvents?: KitchenEventsService,
  ) {}

  async authenticateByPin(dto: CourierPinAuthDto, tenant?: TenantContext) {
    // Before the lookup: a 429 for an unknown phone is the feature, not a leak
    // (ADR-1622 step 4, C4). The raw phone is the key because it is also the
    // lookup value — a variant that misses the row has no account to guess.
    pinRateLimitConsume('courier', tenant?.code, dto.phone);
    // `phone` is unique per tenant among LIVE rows, not globally (ADR-1622
    // step 4b). `deletedAt: null` is what keeps resolveLoginRow's "at most one
    // row per tenant" invariant true — the unique index is partial since the
    // restore window, so a deleted row can hold the same number, and two rows
    // in one tenant would answer a bogus 409 AMBIGUOUS_TENANT. A deleted
    // courier must not authenticate at all either way.
    const courier = await resolveLoginRow(
      tenant,
      () =>
        this.prisma.courier.findMany({
          where: {
            phone: dto.phone,
            deletedAt: null,
            tenant: ACTIVE_TENANT_FILTER,
          },
          take: 2,
        }),
      (tenantId) =>
        // findFirst, not findUnique: dropping the @@unique declaration from the
        // schema took the generated tenantId_phone key with it. Same filters,
        // same single row.
        this.prisma.courier.findFirst({
          // Same as the staff lookup: the declared tenant is re-checked in the
          // query itself, so a tenant suspended between the middleware and here
          // cannot mint a courier token.
          where: {
            tenantId,
            phone: dto.phone,
            deletedAt: null,
            tenant: ACTIVE_TENANT_FILTER,
          },
        }),
    );

    // isActive is checked here, not only in the guard: a deactivated courier
    // must not receive a token at all (ADR-1622 step 3, blocker A2).
    // verifyPin runs unconditionally so a missing row pays the bcrypt cost
    // too (ADR-1622 step 4, C3).
    // `phone` is part of the check because it is a JWT claim and the login key.
    // Nothing nulls it any more — deleteOwnAccount keeps the number for the
    // 7-day restore window — and the rows the old deletion did null are all
    // soft-deleted, so the lookup above already filtered them out. The arm is
    // here for the narrowing the payload needs rather than asserting non-null
    // on an invariant another file has to keep.
    const pinOk = await this.verifyPin(courier, dto.pin);
    if (!courier || !courier.isActive || !courier.phone || !pinOk) {
      throw this.invalidCredentials();
    }

    pinRateLimitReset('courier', tenant?.code, dto.phone);
    return this.issueSession(courier, courier.phone);
  }

  /**
   * Brings back a self-deleted account inside its window (Apple 5.1.1(v) gives
   * the courier the deletion; this is what keeps it survivable — a mis-tap
   * otherwise costs the account, the PIN and the delivery history).
   *
   * A variant of the login rather than a flow of its own: the credential is the
   * same phone + PIN pair, the row it revives is the one authenticateByPin
   * would have found had it not been deleted, and the answer is the same
   * session. Only the set of lookup candidates differs — deleted rows inside
   * the window instead of live ones — which is also why the caller must be
   * anonymous: the deleted courier's JWT is dead by design.
   *
   * `deletedAt` is non-null by construction in the lookup (the comparison
   * excludes nulls) and is written by no one but deleteOwnAccount: the staff
   * DELETE writes isActive alone, so this cannot lift a staff block.
   */
  async restoreAccount(dto: CourierPinAuthDto, tenant?: TenantContext) {
    // The login contour, deliberately shared: this endpoint is a PIN oracle
    // over deleted rows, so an attacker must not get a second, unthrottled
    // budget by asking here instead of /auth/pin. Reset on success for the same
    // reason as the login — a spent budget means nothing once the PIN is known.
    pinRateLimitConsume('courier', tenant?.code, dto.phone);

    // One cutoff for both branches, so the two lookups cannot disagree about
    // what the window is.
    const cutoff = restoreCutoff();

    const courier = await resolveLoginRow(
      tenant,
      () =>
        this.prisma.courier.findMany({
          where: {
            phone: dto.phone,
            deletedAt: { gt: cutoff },
            tenant: ACTIVE_TENANT_FILTER,
          },
          // Most recent deletion first: that is the row whose number the
          // courier still holds in hand.
          orderBy: { deletedAt: 'desc' },
          take: 2,
        }),
      (tenantId) =>
        this.prisma.courier.findFirst({
          where: {
            tenantId,
            phone: dto.phone,
            deletedAt: { gt: cutoff },
            tenant: ACTIVE_TENANT_FILTER,
          },
          orderBy: { deletedAt: 'desc' },
        }),
    );

    // Unconditional, like every other PIN check: an unknown phone pays the
    // bcrypt cost too. A row whose pinHash the window's expiry job has already
    // burned fails here — the credential survives the deletion only because the
    // window keeps it.
    const pinOk = await this.verifyPin(courier, dto.pin);
    if (!courier || !courier.phone || !pinOk) {
      throw this.invalidCredentials();
    }

    // The window predicate rides on the write as well: a restore that raced the
    // expiry job would otherwise revive a row whose data is already burned.
    let count: number;
    try {
      ({ count } = await this.prisma.courier.updateMany({
        where: { id: courier.id, deletedAt: { gt: cutoff } },
        // Exactly the inverse of deleteOwnAccount, and nothing else: name,
        // phone and pinHash were never touched by the deletion, so the account
        // comes back whole.
        data: { deletedAt: null, isActive: true },
      }));
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        // The number was re-issued to another courier while this row was
        // deleted (uq_couriers_tenant_id_phone covers live rows). The database
        // is the guard: two live rows with one number in a tenant is what the
        // login lookup cannot survive, so the restore is refused instead.
        throw new ConflictException({
          statusCode: 409,
          code: 'COURIER_PHONE_EXISTS',
          message: 'Phone is already registered',
        });
      }
      throw error;
    }
    if (count === 0) {
      // The window closed, or a concurrent restore won the row. Both mean the
      // account is not this call's to revive.
      throw this.invalidCredentials();
    }

    pinRateLimitReset('courier', tenant?.code, dto.phone);
    return this.issueSession(courier, courier.phone);
  }

  /**
   * The session both PIN doors answer with — the login and the restore. One
   * payload shape, so the client handles a restored account exactly like a
   * logged-in one. The phone is passed alongside the row because it is the one
   * field the callers have already narrowed to a string (the column is nullable
   * for rows deleted before the window landed).
   */
  private async issueSession(courier: Courier, phone: string) {
    const payload: CourierTokenPayload = {
      sub: courier.id,
      phone,
      branchId: courier.branchId,
      role: 'COURIER',
      type: 'access',
    };
    const token = await this.jwt.signAsync(payload, {
      expiresIn: COURIER_TOKEN_TTL_SECONDS,
    });

    return {
      token,
      tokenType: 'Bearer',
      expiresInSeconds: COURIER_TOKEN_TTL_SECONDS,
      courier: {
        id: courier.id,
        name: courier.name,
        phone,
      },
    };
  }

  /** One body for every failed PIN door, so none of them answers differently. */
  private invalidCredentials(): UnauthorizedException {
    return new UnauthorizedException({
      statusCode: 401,
      code: 'INVALID_CREDENTIALS',
      message: 'Invalid phone or PIN',
    });
  }

  /**
   * Self-service account deletion (Apple 5.1.1(v)): soft delete, no erasure.
   * The row keeps name, phone and PIN hash for the 7-day restore window, so the
   * account can be handed back whole; the data is burned at the end of the
   * window, not here. The row survives because orders reference it — see the
   * courier_account_deletion migration for why hard deletion is not an option.
   *
   * The re-entered PIN is the whole second factor. Unlike the customer flow
   * there is no one-shot deletion token: a courier already holds a secret the
   * client cannot fabricate, and bcrypt-checking it here is cheaper than
   * minting one — and there is nothing to preview, since a courier has no
   * bonus balance to warn about.
   *
   * ponytail: the PIN check is not rate-limited. The caller must already hold a
   * valid courier JWT to reach this method, so the only thing a guess buys is
   * the deletion of an account the guesser already controls. Reuse
   * pinRateLimitConsume with a 'courier-delete' contour if a stolen-token DoS
   * ever shows up.
   */
  async deleteOwnAccount(
    courier: AuthenticatedCourier,
    dto: DeleteCourierAccountDto,
  ): Promise<{ deleted: true }> {
    const row = await this.prisma.courier.findUnique({
      where: { id: courier.id },
    });
    // Mirrors authenticateByPin: the PIN check runs unconditionally, so a row
    // that vanished (or was blocked) between the guard and here pays the bcrypt
    // cost instead of answering faster.
    const pinOk = await this.verifyPin(row, dto.pin);
    if (!row || !row.isActive || !pinOk) {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'INVALID_CREDENTIALS',
        message: 'Invalid PIN',
      });
    }

    // The active-order guard rides on the UPDATE instead of being a count
    // before it. Two statements would leave a window in which the courier
    // claims an order and the account is then deleted out from under a live
    // delivery — and the order would stay assigned to a courier whose token is
    // already dead, with nobody able to transition it.
    //
    // READY/ON_WAY are exactly the states a courier can own (see claimOrder).
    // A branch's unassigned COOKING order does not block: nobody has taken it,
    // so it is not this courier's to finish, and blocking on it would strand
    // the account behind other people's work.
    const { count } = await this.prisma.courier.updateMany({
      where: {
        id: courier.id,
        isActive: true,
        orders: {
          none: { status: { in: [OrderStatus.READY, OrderStatus.ON_WAY] } },
        },
      },
      data: {
        // Deletion flips two flags and touches nothing else: name, phone and
        // PIN hash stay for the 7-day restore window, which is the whole point
        // of the window — a restore that came back as "Удалённый курьер" with a
        // dead PIN would not be one. The phone in particular has to stay, it is
        // the login key. Keeping it no longer blocks the number for a live
        // courier: uq_couriers_tenant_id_phone is partial (deleted_at IS NULL)
        // since 20261014140000_courier_phone_restore_window.
        //
        // Nothing burns the retained data yet — the expiry job is what closes
        // the window. Until it lands, a deleted courier keeps its data
        // indefinitely, so that job is not optional follow-up work.
        isActive: false,
        deletedAt: new Date(),
      },
    });
    if (count === 0) {
      // A row deleted a moment ago never reaches this method — the guard
      // re-reads isActive and answers 401 first — so an order that appeared
      // between the guard and here is the only way to land on zero.
      throw new ConflictException({
        statusCode: 409,
        code: 'ACTIVE_ORDERS_EXIST',
        message: 'Finish the active delivery before deleting the account',
      });
    }

    return { deleted: true };
  }

  /**
   * bcrypt comparison for current hashes. Legacy plaintext rows (written before
   * hashing landed) are checked constant-time via SHA-256 digests and
   * transparently re-hashed to bcrypt on the first successful login.
   */
  private async verifyPin(
    courier: Courier | null,
    pin: string,
  ): Promise<boolean> {
    if (!courier || !courier.pinHash) {
      return constantTimePinCheck(pin, null);
    }
    if (isBcryptHash(courier.pinHash)) {
      return constantTimePinCheck(pin, courier.pinHash);
    }

    const digest = (value: string) => createHash('sha256').update(value).digest();
    if (!timingSafeEqual(digest(pin), digest(courier.pinHash))) {
      // A bare `return false` here would answer in microseconds while a missing
      // row and a bcrypt row both answer in ~100 ms — the same existence channel
      // C3 closed elsewhere, inverted for legacy rows (audit of 3be4a17, Q4a).
      // The helper returns false anyway; it is called for the bcrypt cost.
      await constantTimePinCheck(pin, null);
      return false;
    }

    const pinHash = await bcrypt.hash(pin, PIN_BCRYPT_ROUNDS);
    await this.prisma.courier.update({
      where: { id: courier.id },
      data: { pinHash },
    });
    return true;
  }

  /**
   * Branch-scoped active delivery feed (ADR-1617): unassigned orders of the
   * courier's branch plus the courier's own assigned ones. Branch and courier
   * identity come from the verified JWT — a legacy `branchId` query param is
   * never trusted.
   */
  async getActiveOrders(branchId: string, courierId: string) {
    const orders = await this.prisma.order.findMany({
      where: {
        type: OrderType.DELIVERY,
        branchId,
        status: {
          in: [OrderStatus.COOKING, OrderStatus.READY, OrderStatus.ON_WAY],
        },
        OR: [{ courierId: null }, { courierId }],
      },
      include: {
        customer: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    return orders.map((order) => this.toCourierOrder(order));
  }

  /**
   * Courier history (ADR-1621): completed and cancelled deliveries owned by
   * this courier, newest first. Date bounds are inclusive; cancelled orders
   * fall back to cancelledAt when completedAt is null.
   */
  async getHistory(courierId: string, query: CourierHistoryQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const range: { gte?: Date; lte?: Date } = {};
    if (query.from) range.gte = new Date(query.from);
    if (query.to) range.lte = new Date(query.to);

    const where: Prisma.OrderWhereInput = {
      type: OrderType.DELIVERY,
      courierId,
      status: { in: [OrderStatus.COMPLETED, OrderStatus.CANCELLED] },
      ...(Object.keys(range).length > 0
        ? {
            OR: [
              { completedAt: range },
              { completedAt: null, cancelledAt: range },
            ],
          }
        : {}),
    };

    const [records, total] = await this.prisma.$transaction([
      this.prisma.order.findMany({
        where,
        include: { customer: true },
        orderBy: [{ completedAt: 'desc' }, { createdAt: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.order.count({ where }),
    ]);

    return {
      data: records.map((order) => this.toCourierOrder(order)),
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  /**
   * Courier-driven status transition (ADR-1617):
   *   unassigned READY  + target READY     -> atomic claim
   *   own READY         + target ON_WAY    -> delivery started
   *   own ON_WAY        + target COMPLETED -> delivery finished
   * Everything else is rejected with the ADR-mandated error codes.
   */
  async updateCourierOrderStatus(
    courier: AuthenticatedCourier,
    orderId: string,
    dto: UpdateCourierOrderStatusDto,
  ) {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    // Cross-branch orders answer 404 — their existence is never leaked.
    if (!order || order.branchId !== courier.branchId) {
      throw new NotFoundException({
        statusCode: 404,
        code: 'ORDER_NOT_FOUND',
        message: `Order ${orderId} not found`,
      });
    }

    const updated =
      dto.status === OrderStatus.READY
        ? await this.claimOrder(courier, order)
        : await this.transitionOwnOrder(courier, order, dto.status);

    this.emitOrderChanged(updated);
    // Kitchen POS (ADR-1618): a courier taking the order ON_WAY (or
    // completing it) removes it from the branch kitchen board.
    await this.kitchenEvents?.publishOrderChanged(updated.id);

    // Loyalty (ADR-1614): same idempotent cashback rule as the staff endpoint.
    if (updated.status === OrderStatus.COMPLETED) {
      await this.loyalty.earnCashback(updated.id);
    }

    return this.toCourierOrder(updated);
  }

  /** Claim: unassigned READY order becomes the courier's own READY order. */
  private async claimOrder(
    courier: AuthenticatedCourier,
    order: Order,
  ): Promise<Order> {
    if (order.courierId !== null) {
      throw new ConflictException({
        statusCode: 409,
        code: 'ORDER_ALREADY_ASSIGNED',
        message: 'Order is already assigned to a courier',
      });
    }
    if (order.status !== OrderStatus.READY) {
      throw this.invalidTransition(order.status, OrderStatus.READY);
    }

    // One active delivery per courier (READY or ON_WAY owned by them).
    const activeCount = await this.prisma.order.count({
      where: {
        courierId: courier.id,
        status: { in: [OrderStatus.READY, OrderStatus.ON_WAY] },
      },
    });
    if (activeCount > 0) {
      throw new ConflictException({
        statusCode: 409,
        code: 'COURIER_HAS_ACTIVE_ORDER',
        message: 'Finish the active delivery before claiming a new order',
      });
    }

    // Atomic claim: only one concurrent claimant flips courierId null -> own.
    // The audit row lands in the same transaction so status and history can
    // never drift apart (ADR-608: every change is recorded).
    const { count } = await this.prisma.$transaction(async (tx) => {
      const result = await tx.order.updateMany({
        where: { id: order.id, status: OrderStatus.READY, courierId: null },
        data: { courierId: courier.id, version: { increment: 1 } },
      });
      if (result.count > 0) {
        await tx.orderStatusHistory.create({
          data: {
            orderId: order.id,
            previousStatus: OrderStatus.READY,
            newStatus: OrderStatus.READY,
            changedBy: courier.id,
            reason: 'COURIER_CLAIM',
          },
        });
      }
      return result;
    });
    if (count === 0) {
      throw new ConflictException({
        statusCode: 409,
        code: 'ORDER_ALREADY_ASSIGNED',
        message: 'Order was just claimed by another courier',
      });
    }
    return this.prisma.order.findUniqueOrThrow({
      where: { id: order.id },
      include: { customer: true },
    });
  }

  /** ON_WAY / COMPLETED transitions of the courier's own order. */
  private async transitionOwnOrder(
    courier: AuthenticatedCourier,
    order: Order,
    target: 'ON_WAY' | 'COMPLETED',
  ): Promise<Order> {
    if (order.courierId !== courier.id) {
      throw new ForbiddenException({
        statusCode: 403,
        code: 'ORDER_NOT_ASSIGNED_TO_COURIER',
        message: 'Order is not assigned to this courier',
      });
    }
    const expected =
      target === OrderStatus.ON_WAY ? OrderStatus.READY : OrderStatus.ON_WAY;
    if (order.status !== expected) {
      throw this.invalidTransition(order.status, target);
    }

    // Transition + audit row atomically (ADR-608). changedBy carries the
    // courier UUID; kitchen transitions use kitchenTerminalId instead.
    const { count } = await this.prisma.$transaction(async (tx) => {
      const result = await tx.order.updateMany({
        where: { id: order.id, status: expected, courierId: courier.id },
        data: {
          status: target,
          version: { increment: 1 },
          ...(target === OrderStatus.COMPLETED ? { completedAt: new Date() } : {}),
        },
      });
      if (result.count > 0) {
        await tx.orderStatusHistory.create({
          data: {
            orderId: order.id,
            previousStatus: expected,
            newStatus: target,
            changedBy: courier.id,
          },
        });
      }
      return result;
    });
    if (count === 0) {
      throw this.invalidTransition(order.status, target);
    }
    return this.prisma.order.findUniqueOrThrow({
      where: { id: order.id },
      include: { customer: true },
    });
  }

  /**
   * Courier location intake (ADR-1617): accepts a fix only for the courier's
   * own ON_WAY order. Range/format checks live in ReportCourierLocationDto;
   * here: ownership, status, clock skew and a per-courier rate limit.
   * Raw coordinates are never logged.
   */
  async reportCourierLocation(
    courier: AuthenticatedCourier,
    dto: ReportCourierLocationDto,
  ): Promise<{ accepted: true }> {
    const order = await this.prisma.order.findUnique({
      where: { id: dto.orderId },
    });
    if (!order || order.branchId !== courier.branchId) {
      throw new NotFoundException({
        statusCode: 404,
        code: 'ORDER_NOT_FOUND',
        message: `Order ${dto.orderId} not found`,
      });
    }
    if (order.courierId !== courier.id) {
      throw new ForbiddenException({
        statusCode: 403,
        code: 'ORDER_NOT_ASSIGNED_TO_COURIER',
        message: 'Order is not assigned to this courier',
      });
    }
    if (order.status !== OrderStatus.ON_WAY) {
      throw new ConflictException({
        statusCode: 409,
        code: 'ORDER_NOT_ON_WAY',
        message: 'Location is accepted only while the order is ON_WAY',
      });
    }

    const capturedAtMs = Date.parse(dto.capturedAt);
    if (
      Number.isNaN(capturedAtMs) ||
      Math.abs(Date.now() - capturedAtMs) > COURIER_LOCATION_MAX_CLOCK_SKEW_MS
    ) {
      throw new HttpException(
        {
          statusCode: 400,
          code: 'LOCATION_CLOCK_SKEW',
          message: 'capturedAt deviates from server time beyond the allowed skew',
        },
        400,
      );
    }

    const now = Date.now();
    const last = this.lastLocationAt.get(courier.id) ?? 0;
    if (now - last < COURIER_LOCATION_MIN_INTERVAL_MS) {
      throw new HttpException(
        {
          statusCode: 429,
          code: 'LOCATION_RATE_LIMITED',
          message: 'Location reports are accepted at most once per few seconds',
        },
        429,
      );
    }
    this.lastLocationAt.set(courier.id, now);

    this.events.emitCourierLocation({
      orderId: order.id,
      courierId: courier.id,
      branchId: courier.branchId,
      latitude: dto.latitude,
      longitude: dto.longitude,
      accuracyMeters: dto.accuracyMeters,
      capturedAt: dto.capturedAt,
    });
    return { accepted: true };
  }

  private invalidTransition(
    from: OrderStatus,
    to: OrderStatus,
  ): ConflictException {
    return new ConflictException({
      statusCode: 409,
      code: 'INVALID_ORDER_STATUS_TRANSITION',
      message: `Courier transition ${from} -> ${to} is not allowed`,
    });
  }

  private emitOrderChanged(order: Order) {
    this.events.emitOrderEvent({
      orderId: order.id,
      orderNumber: order.orderNumber,
      status: order.status,
      branchId: order.branchId,
      courierId: order.courierId,
      deliveryAddress: order.deliveryAddress,
      totalRubles: Math.round(Number(order.totalAmount)),
      timestamp: new Date().toISOString(),
    });
    this.events.emitOrderTrackingEvent({
      orderId: order.id,
      status: order.status,
      courierId: order.courierId,
      version: order.version,
      estimatedReadyAt: order.estimatedReadyAt?.toISOString() ?? null,
      timestamp: new Date().toISOString(),
    });
  }

  // phone is nullable: a deleted customer's number is erased, and the courier
  // must see an empty contact rather than anything fabricated.
  private toCourierOrder(order: Order & { customer?: { phone: string | null } | null }) {
    return {
      id: order.id,
      number: order.orderNumber,
      status: order.status,
      type: order.type,
      totalRubles: Math.round(Number(order.totalAmount)),
      paymentMethod:
        order.paymentMethod === PaymentMethod.ONLINE ? 'onlinePaid' : 'onDelivery',
      address: {
        street: order.deliveryAddress || 'Адрес не указан',
        lat: order.deliveryLatitude ? Number(order.deliveryLatitude) : null,
        lon: order.deliveryLongitude ? Number(order.deliveryLongitude) : null,
      },
      clientPhone: order.customer?.phone || '',
      clientComment: order.comment,
      branchId: order.branchId,
      courierId: order.courierId,
      createdAt: order.createdAt.toISOString(),
    };
  }
}

/**
 * Start of the restore window: a deletion newer than this can still be undone.
 * `deletedAt: null` is deliberately not covered — a live row is not a candidate
 * and the comparison says so by itself.
 */
export function restoreCutoff(now: Date = new Date()): Date {
  return new Date(now.getTime() - COURIER_RESTORE_WINDOW_DAYS * 24 * 60 * 60 * 1000);
}
