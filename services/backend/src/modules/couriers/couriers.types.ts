/** JWT payload of the courier access token (POST /couriers/auth/pin). */
export interface CourierTokenPayload {
  /** Courier id (couriers.id). */
  sub: string;
  phone: string;
  /** Branch the courier is attached to (branches.id). */
  branchId: string;
  role: 'COURIER';
  type: 'access';
}

/**
 * Courier identity attached to the request by CourierJwtAuthGuard. Like
 * branchId, `tenantId` comes from the authoritative row, never from the token:
 * the SSE stream uses it to close itself when the tenant is suspended
 * (ADR-1622 C5).
 */
export interface AuthenticatedCourier {
  id: string;
  phone: string;
  branchId: string;
  tenantId: string;
  role: 'COURIER';
}

/** Minimal request shape used by the courier guard (avoids express type coupling). */
export interface RequestWithCourier {
  headers: { authorization?: string };
  courier?: AuthenticatedCourier;
}
