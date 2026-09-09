import { OrderStatus } from '@prisma/client';

/** JWT payload of the kitchen terminal access token (POST /kitchen/auth/pin, ADR-1618). */
export interface KitchenTokenPayload {
  /** Kitchen terminal id (kitchen_terminals.id). */
  sub: string;
  /** Branch the terminal is bound to (branches.id). */
  branchId: string;
  role: 'KITCHEN';
  type: 'access';
}

/** Terminal identity attached to the request by KitchenJwtAuthGuard. */
export interface AuthenticatedKitchenTerminal {
  id: string;
  code: string;
  name: string;
  branchId: string;
  role: 'KITCHEN';
}

/** Minimal request shape used by the kitchen guard (avoids express type coupling). */
export interface RequestWithKitchen {
  headers: { authorization?: string };
  kitchenTerminal?: AuthenticatedKitchenTerminal;
}

/**
 * Statuses the kitchen board shows and drives. ON_DELIVERY orders enter as
 * NEW and are visible immediately; paid ONLINE orders enter as CONFIRMED.
 * READY -> COMPLETED belongs to POS/courier, not the KDS.
 */
export const KITCHEN_ACTIVE_STATUSES = [
  OrderStatus.NEW,
  OrderStatus.CONFIRMED,
  OrderStatus.COOKING,
  OrderStatus.READY,
] as const;

export type KitchenOrderStatus = (typeof KITCHEN_ACTIVE_STATUSES)[number];

export interface KitchenOrderItemDto {
  id: string;
  name: string;
  quantity: number;
  comment: string | null;
  modifiers: Array<{ id: string; name: string; quantity: number }>;
}

/**
 * Board projection (ADR-1618): no customer phone/address and no payment
 * details — only what the kitchen needs to cook. `version` feeds optimistic
 * concurrency, the server timestamps feed the stable status timers.
 */
export interface KitchenOrderDto {
  id: string;
  orderNumber: string;
  version: number;
  status: KitchenOrderStatus;
  type: 'DINE_IN' | 'TAKEAWAY' | 'DELIVERY';
  tableNumber: string | null;
  comment: string | null;
  confirmedAt: string;
  cookingStartedAt: string | null;
  readyAt: string | null;
  items: KitchenOrderItemDto[];
}

/** GET /kitchen/orders/active response: the branch board plus server time for clock-offset math. */
export interface KitchenBoardSnapshotDto {
  serverTime: string;
  orders: KitchenOrderDto[];
}

/** SSE event envelope of the kitchen realtime contract (ADR-1618, eventVersion 1). */
export interface KitchenOrderEventV1 {
  eventId: string;
  eventType: 'kitchen.order.upserted' | 'kitchen.order.removed';
  eventVersion: 1;
  occurredAt: string;
  orderId: string;
  orderVersion: number;
  order: KitchenOrderDto | null;
}
