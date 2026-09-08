import { createHash, timingSafeEqual } from 'crypto';
import * as bcrypt from 'bcryptjs';
import {
  ConflictException,
  ForbiddenException,
  HttpException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../prisma/prisma.service';
import { Courier, Order, OrderStatus, OrderType } from '@prisma/client';
import { CourierPinAuthDto } from './dto/courier-auth.dto';
import { UpdateCourierOrderStatusDto } from './dto/update-courier-order-status.dto';
import { ReportCourierLocationDto } from './dto/report-courier-location.dto';
import {
  COURIER_LOCATION_MAX_CLOCK_SKEW_MS,
  COURIER_LOCATION_MIN_INTERVAL_MS,
  COURIER_TOKEN_TTL_SECONDS,
  PIN_BCRYPT_ROUNDS,
} from './couriers.config';
import { AuthenticatedCourier, CourierTokenPayload } from './couriers.types';
import { CouriersEventsService } from './couriers-events.service';
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
  ) {}

  async authenticateByPin(dto: CourierPinAuthDto) {
    let courier = await this.prisma.courier.findUnique({
      where: { phone: dto.phone },
    });

    if (!courier) {
      const defaultBranch = await this.prisma.branch.findFirst();
      const defaultBrand = await this.prisma.brand.findFirst();

      if (!defaultBranch || !defaultBrand) {
        throw new UnauthorizedException('Branch or Brand configuration is missing');
      }

      courier = await this.prisma.courier.create({
        data: {
          name: 'Курьер ' + dto.phone.slice(-4),
          phone: dto.phone,
          pinHash: await bcrypt.hash(dto.pin, PIN_BCRYPT_ROUNDS),
          brandId: defaultBrand.id,
          branchId: defaultBranch.id,
        },
      });
    } else if (!(await this.verifyPin(courier, dto.pin))) {
      throw new UnauthorizedException('Invalid PIN code');
    }

    const payload: CourierTokenPayload = {
      sub: courier.id,
      phone: courier.phone,
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
        phone: courier.phone,
      },
    };
  }

  /**
   * bcrypt comparison for current hashes. Legacy plaintext rows (written before
   * hashing landed) are checked constant-time via SHA-256 digests and
   * transparently re-hashed to bcrypt on the first successful login.
   */
  private async verifyPin(courier: Courier, pin: string): Promise<boolean> {
    if (isBcryptHash(courier.pinHash)) {
      return bcrypt.compare(pin, courier.pinHash);
    }

    const digest = (value: string) => createHash('sha256').update(value).digest();
    if (!timingSafeEqual(digest(pin), digest(courier.pinHash))) {
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
    const { count } = await this.prisma.order.updateMany({
      where: { id: order.id, status: OrderStatus.READY, courierId: null },
      data: { courierId: courier.id, version: { increment: 1 } },
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

    const { count } = await this.prisma.order.updateMany({
      where: { id: order.id, status: expected, courierId: courier.id },
      data: {
        status: target,
        version: { increment: 1 },
        ...(target === OrderStatus.COMPLETED ? { completedAt: new Date() } : {}),
      },
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

  private toCourierOrder(order: Order & { customer?: { phone: string } | null }) {
    return {
      id: order.id,
      number: order.orderNumber,
      status: order.status,
      type: order.type,
      totalRubles: Math.round(Number(order.totalAmount)),
      paymentMethod: 'onlinePaid',
      address: {
        street: order.deliveryAddress || 'Адрес не указан',
      },
      clientPhone: order.customer?.phone || '',
      clientComment: order.comment,
      branchId: order.branchId,
      courierId: order.courierId,
      createdAt: order.createdAt.toISOString(),
    };
  }
}
