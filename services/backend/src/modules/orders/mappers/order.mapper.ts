import { Prisma } from '@prisma/client';
import { OrderEntity } from '../entities/order.entity';

export const ORDER_INCLUDE = {
  items: {
    orderBy: { createdAt: 'asc' as const },
    include: { modifiers: true },
  },
} satisfies Prisma.OrderInclude;

export type OrderRecord = Prisma.OrderGetPayload<{ include: typeof ORDER_INCLUDE }>;

function iso(value: Date | null | undefined): string | null {
  return value ? value.toISOString() : null;
}

export function toOrderEntity(record: OrderRecord): OrderEntity {
  return {
    id: record.id,
    orderNumber: record.orderNumber,
    status: record.status,
    type: record.type,
    brandId: record.brandId,
    branchId: record.branchId,
    tableNumber: record.tableNumber,
    deliveryAddress: record.deliveryAddress,
    comment: record.comment,
    subtotalAmount: record.subtotalAmount.toNumber(),
    totalAmount: record.totalAmount.toNumber(),
    currency: record.currency,
    estimatedReadyAt: iso(record.estimatedReadyAt),
    completedAt: iso(record.completedAt),
    cancelledAt: iso(record.cancelledAt),
    createdAt: record.createdAt.toISOString(),
    updatedAt: record.updatedAt.toISOString(),
    items: record.items.map((item) => ({
      id: item.id,
      menuItemId: item.menuItemId,
      name: item.name,
      quantity: item.quantity,
      unitPrice: item.unitPrice.toNumber(),
      totalAmount: item.totalAmount.toNumber(),
      comment: item.comment,
      modifiers: item.modifiers.map((modifier) => ({
        id: modifier.id,
        modifierItemId: modifier.modifierItemId,
        name: modifier.name,
        priceDelta: modifier.priceDelta.toNumber(),
        quantity: modifier.quantity,
      })),
    })),
  };
}
