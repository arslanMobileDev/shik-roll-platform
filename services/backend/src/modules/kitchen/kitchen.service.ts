import { CookActor } from '../cooks/cooks.dto';
import { COOK_TTL_MS } from '../cooks/cook-session.service';
import * as bcrypt from 'bcryptjs';
import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { OrderStatus, OrderType } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { CouriersEventsService } from '../couriers/couriers-events.service';
import { OrdersEventsService } from '../orders/orders-events.service';
import { ORDER_INCLUDE } from '../orders/mappers/order.mapper';
import { KITCHEN_TOKEN_TTL_SECONDS } from './kitchen.config';
import { toKitchenOrder } from './kitchen.mapper';
import { KitchenEventsService } from './kitchen-events.service';
import { KitchenPinAuthDto } from './dto/kitchen-auth.dto';
import { UpdateKitchenOrderStatusDto } from './dto/kitchen-order-status.dto';
import {
  AuthenticatedKitchenTerminal,
  KitchenOrderDto,
  KitchenTokenPayload,
} from './kitchen.types';

@Injectable()
export class KitchenService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly events: KitchenEventsService,
    private readonly courierEvents: CouriersEventsService,
    private readonly orderEvents: OrdersEventsService,
  ) {}

  /**
   * Terminal sign-in (ADR-1618): bcrypt PIN check + active flag + branch
   * availability, then a JWT scoped to one work shift. Unlike the courier
   * flow, terminals are provisioned by ops — an unknown code is never
   * auto-created, and the failure message is uniform so it never leaks
   * whether the code exists. PIN and token are never logged.
   */
  async authenticateByPin(dto: KitchenPinAuthDto) {
    const terminal = await this.prisma.kitchenTerminal.findUnique({
      where: { code: dto.terminalCode },
    });
    const pinOk =
      terminal !== null && (await bcrypt.compare(dto.pin, terminal.pinHash));
    if (!terminal || !terminal.isActive || !pinOk) {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'UNAUTHORIZED',
        message: 'Invalid terminal code or PIN',
      });
    }

    const branch = await this.prisma.branch.findUnique({
      where: { id: terminal.branchId },
    });
    if (!branch) {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'TERMINAL_BRANCH_UNAVAILABLE',
        message: 'Terminal branch is unavailable',
      });
    }

    const payload: KitchenTokenPayload = {
      sub: terminal.id,
      branchId: terminal.branchId,
      role: 'KITCHEN',
      type: 'access',
    };
    const token = await this.jwt.signAsync(payload, {
      expiresIn: KITCHEN_TOKEN_TTL_SECONDS,
    });

    return {
      token,
      tokenType: 'Bearer',
      expiresInSeconds: KITCHEN_TOKEN_TTL_SECONDS,
      terminal: {
        id: terminal.id,
        code: terminal.code,
        name: terminal.name,
        branchId: terminal.branchId,
      },
    };
  }

  /**
   * Kitchen-driven transition (ADR-1618): the terminal owns
   * NEW/CONFIRMED -> COOKING and COOKING -> READY. Branch ownership comes from
   * the JWT, optimistic concurrency from `expectedVersion`, and the status
   * write + server timestamps + audit history land in ONE transaction.
   */
  async updateOrderStatus(
    terminal: AuthenticatedKitchenTerminal,
    orderId: string,
    dto: UpdateKitchenOrderStatusDto,
    cook?: CookActor,
  ): Promise<KitchenOrderDto> {
    const target =
      dto.status === 'COOKING' ? OrderStatus.COOKING : OrderStatus.READY;
    const now = new Date();

    const order = await this.prisma.order.findFirst({
      where: { id: orderId, deletedAt: null },
    });
    if (!order) {
      throw new NotFoundException({
        statusCode: 404,
        code: 'ORDER_NOT_FOUND',
        message: `Order ${orderId} not found`,
      });
    }
    // ADR-1618: a foreign branch is a stable 403 (deliberately unlike the
    // courier 404 — the kitchen operates a shared board inside one branch).
    if (order.branchId !== terminal.branchId) {
      throw new ForbiddenException({
        statusCode: 403,
        code: 'ORDER_BRANCH_FORBIDDEN',
        message: 'Order belongs to a different branch',
      });
    }
    const validSource =
      target === OrderStatus.COOKING
        ? order.status === OrderStatus.NEW || order.status === OrderStatus.CONFIRMED
        : order.status === OrderStatus.COOKING;
    if (!validSource) {
      throw this.invalidTransition(order.status, target);
    }
    const from = order.status;

    const updated = await this.prisma.$transaction(async (tx) => {
      if (cook) {
        const shifts = await tx.$queryRaw<Array<{id:string}>>`SELECT id FROM cook_shifts WHERE id = ${cook.shiftId}::uuid AND cook_id = ${cook.id}::uuid AND terminal_id = ${terminal.id}::uuid AND branch_id = ${terminal.branchId}::uuid AND ended_at IS NULL AND started_at > ${new Date(Date.now()-COOK_TTL_MS)} FOR UPDATE`;
        if (!shifts.length) throw new UnauthorizedException('Cook shift is closed');
      }
      const { count } = await tx.order.updateMany({
        where: {
          id: orderId,
          branchId: terminal.branchId,
          status: from,
          version: dto.expectedVersion,
        },
        data: {
          status: target,
          version: { increment: 1 },
          // ADR-1618: starting COOKING from NEW is an implicit confirmation —
          // record confirmedAt so the data contract holds even when the
          // kitchen board skips the explicit CONFIRMED step.
          ...(target === OrderStatus.COOKING
            ? {
                cookingStartedAt: now,
                ...(from === OrderStatus.NEW ? { confirmedAt: now } : {}),
              }
            : { readyAt: now }),
        },
      });
      if (count === 0) {
        // Lost a race: re-read inside the transaction and disambiguate —
        // a moved-on status is INVALID_ORDER_STATUS_TRANSITION, a stale
        // version is ORDER_VERSION_CONFLICT.
        const fresh = await tx.order.findUnique({
          where: { id: orderId },
          select: { status: true },
        });
        if (fresh && fresh.status !== from) {
          throw this.invalidTransition(fresh.status, target);
        }
        throw new ConflictException({
          statusCode: 409,
          code: 'ORDER_VERSION_CONFLICT',
          message: `Order ${orderId} changed on the board — refresh and retry`,
        });
      }
      // Attribution comes only from the verified cook session, never from the DTO.
      await tx.orderStatusHistory.create({
        data: {
          orderId,
          previousStatus: from,
          newStatus: target,
          kitchenTerminalId: terminal.id,
          cookId: cook?.id ?? null,
          shiftId: cook?.shiftId ?? null,
        },
      });
      return tx.order.findUniqueOrThrow({
        where: { id: orderId },
        include: ORDER_INCLUDE,
      });
    });

    // Publish the committed transition once to each existing channel.
    const timestamp = new Date().toISOString();
    this.courierEvents.emitOrderTrackingEvent({
      orderId: updated.id,
      status: updated.status,
      courierId: updated.courierId,
      version: updated.version,
      estimatedReadyAt: updated.estimatedReadyAt?.toISOString() ?? null,
      timestamp,
    });
    if (updated.type === OrderType.DELIVERY) {
      this.courierEvents.emitOrderEvent({
        orderId: updated.id,
        orderNumber: updated.orderNumber,
        status: updated.status,
        branchId: updated.branchId,
        courierId: updated.courierId,
        deliveryAddress: updated.deliveryAddress,
        totalRubles: Math.round(Number(updated.totalAmount)),
        timestamp,
      });
    }
    this.orderEvents.emitKdsEvent({
      eventType: 'ORDER_STATUS_CHANGED',
      orderId: updated.id,
      orderNumber: updated.orderNumber,
      branchId: updated.branchId,
      status: updated.status,
      timestamp,
    });
    await this.events.publishOrderChanged(updated.id);
    return toKitchenOrder(updated);
  }

  private invalidTransition(
    from: OrderStatus,
    to: OrderStatus,
  ): ConflictException {
    return new ConflictException({
      statusCode: 409,
      code: 'INVALID_ORDER_STATUS_TRANSITION',
      message: `Kitchen transition ${from} -> ${to} is not allowed`,
    });
  }
}
