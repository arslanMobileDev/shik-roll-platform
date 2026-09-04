import { Injectable } from '@nestjs/common';
import { OrderStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { ORDER_INCLUDE, OrderRecord } from './mappers/order.mapper';

export interface OrderListFilter {
  brandId?: string;
  branchId?: string;
  status?: OrderStatus;
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
      ...(filter.status ? { status: filter.status } : {}),
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

  create(data: Prisma.OrderCreateInput): Promise<OrderRecord> {
    return this.prisma.order.create({ data, include: ORDER_INCLUDE });
  }

  /** Transition the status and append to history in one atomic operation (BE-907). */
  async transitionStatus(
    id: string,
    from: OrderStatus,
    to: OrderStatus,
    changedBy: string | undefined,
    reason: string | undefined,
  ): Promise<OrderRecord> {
    const terminalPatch: Prisma.OrderUncheckedUpdateInput = {};
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

  async nextOrderSequence(branchId: string): Promise<number> {
    // Daily sequence per branch; order_number = <branch>-<yyyymmdd>-<seq>.
    const dayStart = new Date();
    dayStart.setUTCHours(0, 0, 0, 0);
    return this.prisma.order.count({
      where: { branchId, createdAt: { gte: dayStart } },
    });
  }
}
