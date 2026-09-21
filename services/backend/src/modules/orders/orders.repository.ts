import { Injectable } from '@nestjs/common';
import { OrderStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { ORDER_INCLUDE, OrderRecord } from './mappers/order.mapper';

export interface OrderListFilter {
  brandId?: string;
  branchId?: string;
  statuses?: OrderStatus[];
  excludePendingPayment?: boolean;
  customerId?: string;
  page: number;
  limit: number;
}

/**
 * Order bounded context data access (ADR-1607: Prisma only).
 */
@Injectable()
export class OrdersRepository {
  constructor(private readonly prisma: PrismaService) {}

  async list(
    filter: OrderListFilter,
  ): Promise<{ records: OrderRecord[]; total: number }> {
    const where: Prisma.OrderWhereInput = {
      deletedAt: null,
      ...(filter.brandId ? { brandId: filter.brandId } : {}),
      ...(filter.branchId ? { branchId: filter.branchId } : {}),
      ...(filter.statuses?.length
        ? { status: { in: filter.statuses } }
        : filter.excludePendingPayment
          ? { status: { not: OrderStatus.PENDING_PAYMENT } }
          : {}),
      ...(filter.customerId ? { customerId: filter.customerId } : {}),
    };

    const [records, total] = await this.prisma.$transaction([
      this.prisma.order.findMany({
        where,
        include: ORDER_INCLUDE,
        orderBy: { createdAt: 'desc' },
        skip: (filter.page - 1) * filter.limit,
        take: filter.limit,
      }),
      this.prisma.order.count({ where }),
    ]);

    return { records, total };
  }

  findById(id: string): Promise<OrderRecord | null> {
    return this.prisma.order.findFirst({
      where: { id, deletedAt: null },
      include: ORDER_INCLUDE,
    });
  }

  /**
   * Create the order. Accepts an ambient transaction client so the checkout
   * bonus spend (ADR-1614) commits in the same transaction as the order.
   */
  create(
    data: Prisma.OrderCreateInput,
    tx?: Prisma.TransactionClient,
  ): Promise<OrderRecord> {
    const client = tx ?? this.prisma;
    return client.order.create({ data, include: ORDER_INCLUDE });
  }

  /** Transition the status and append to history in one atomic operation (BE-907). */
  async transitionStatus(
    id: string,
    from: OrderStatus,
    to: OrderStatus,
    changedBy: string | undefined,
    reason: string | undefined,
    courierId?: string | undefined,
  ): Promise<OrderRecord> {
    const terminalPatch: Prisma.OrderUncheckedUpdateInput = {};
    if (to === OrderStatus.CONFIRMED) terminalPatch.confirmedAt = new Date();
    if (to === OrderStatus.COOKING) terminalPatch.cookingStartedAt = new Date();
    if (to === OrderStatus.READY) terminalPatch.readyAt = new Date();
    if (to === OrderStatus.COMPLETED) terminalPatch.completedAt = new Date();
    if (to === OrderStatus.CANCELLED) {
      terminalPatch.cancelledAt = new Date();
      terminalPatch.cancelReason = reason ?? null;
    }

    const [record] = await this.prisma.$transaction([
      this.prisma.order.update({
        where: { id },
        data: {
          status: to,
          ...(courierId !== undefined ? { courierId } : {}),
          ...terminalPatch,
          version: { increment: 1 },
        },
        include: ORDER_INCLUDE,
      }),
      this.prisma.orderStatusHistory.create({
        data: {
          orderId: id,
          previousStatus: from,
          newStatus: to,
          changedBy: changedBy ?? null,
          reason: reason ?? null,
        },
      }),
    ]);

    return record;
  }

  async setAmounts(
    id: string,
    subtotalAmount: Prisma.Decimal,
    totalAmount: Prisma.Decimal,
  ): Promise<void> {
    await this.prisma.order.update({
      where: { id },
      data: { subtotalAmount, totalAmount },
    });
  }

  /**
   * Allocates the next daily sequence value for a branch-day.
   *
   * One atomic statement: the row is created on first use and incremented on
   * every later call, so concurrent creates cannot observe the same value.
   * Gaps are expected — a rolled-back create burns its value.
   */
  async nextOrderSequence(
    branchId: string,
    now: Date = new Date(),
  ): Promise<{ sequence: number; day: Date }> {
    const day = new Date(now);
    day.setUTCHours(0, 0, 0, 0);
    // Bind the day as an explicit date string: Prisma binds a JS Date as
    // timestamptz, so a `::date` cast on it would resolve in the session
    // timezone and key the counter on the previous day under a negative
    // UTC offset.
    const dayKey = day.toISOString().slice(0, 10); // 'YYYY-MM-DD'
    const rows = await this.prisma.$queryRaw<{ last_value: number }[]>`
      INSERT INTO "order_sequences" ("branch_id", "day", "last_value", "updated_at")
      VALUES (${branchId}::uuid, ${dayKey}::date, 1, now())
      ON CONFLICT ("branch_id", "day")
      DO UPDATE SET "last_value" = "order_sequences"."last_value" + 1,
                    "updated_at" = now()
      RETURNING "last_value"
    `;
    return { sequence: rows[0].last_value, day };
  }
}
