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

/** Courier identity attached to the request by CourierJwtAuthGuard. */
export interface AuthenticatedCourier {
  id: string;
  phone: string;
  branchId: string;
  role: 'COURIER';
}

/** Minimal request shape used by the courier guard (avoids express type coupling). */
export interface RequestWithCourier {
  headers: { authorization?: string };
  courier?: AuthenticatedCourier;
}
