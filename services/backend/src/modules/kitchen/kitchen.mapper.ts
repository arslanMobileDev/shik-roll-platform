import { OrderRecord } from '../orders/mappers/order.mapper';
import { KitchenOrderDto, KitchenOrderStatus } from './kitchen.types';

function iso(value: Date | null | undefined): string | null {
  return value ? value.toISOString() : null;
}

/**
 * Order -> kitchen board projection (ADR-1618). Deliberately narrower than
 * OrderEntity: no customer phone/address, no payment details, no money.
 * `confirmedAt` falls back to `createdAt` for legacy rows written before the
 * timestamp columns existed (the migration backfills active orders).
 */
export function toKitchenOrder(record: OrderRecord): KitchenOrderDto {
  return {
    id: record.id,
    orderNumber: record.orderNumber,
    version: record.version,
    status: record.status as KitchenOrderStatus,
    type: record.type,
    tableNumber: record.tableNumber,
    comment: record.comment,
    confirmedAt: (record.confirmedAt ?? record.createdAt).toISOString(),
    cookingStartedAt: iso(record.cookingStartedAt),
    readyAt: iso(record.readyAt),
    items: record.items.map((item) => ({
      id: item.id,
      name: item.name,
      quantity: item.quantity,
      comment: item.comment,
      modifiers: item.modifiers.map((modifier) => ({
        id: modifier.id,
        name: modifier.name,
        quantity: modifier.quantity,
      })),
    })),
  };
}

/**
 * FIFO sort key within a board column (ADR-1618): the server timestamp of
 * entering the current status, with fallbacks for legacy rows.
 */
export function statusEntryTime(order: KitchenOrderDto): string {
  switch (order.status) {
    case 'NEW':
    case 'CONFIRMED':
      return order.confirmedAt;
    case 'COOKING':
      return order.cookingStartedAt ?? order.confirmedAt;
    case 'READY':
      return order.readyAt ?? order.cookingStartedAt ?? order.confirmedAt;
  }
}

/** Board ordering: oldest status entry first (FIFO per column). */
export function compareByStatusEntry(
  a: KitchenOrderDto,
  b: KitchenOrderDto,
): number {
  return statusEntryTime(a).localeCompare(statusEntryTime(b));
}
