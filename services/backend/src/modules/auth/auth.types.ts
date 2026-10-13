import { CustomerRole } from '@prisma/client';

/** JWT payload of the guest access/refresh tokens. */
export interface CustomerTokenPayload {
  /** Customer id (customers.id) */
  sub: string;
  /**
   * Informational only — no endpoint reads it. Nullable because a deleted
   * customer's phone is erased; the row check in JwtAuthGuard rejects those
   * tokens anyway, so an authenticated request always has a phone.
   */
  phone?: string | null;
  /** Present on tokens issued after the role column landed. */
  role?: CustomerRole;
  type: 'access' | 'refresh';
}

/** Guest identity attached to the request by the JWT guards. */
export interface AuthenticatedCustomer {
  id: string;
  phone: string | null;
  role: CustomerRole;
}

/** Minimal request shape used by the guards (avoids express type coupling). */
export interface RequestWithCustomer {
  headers: { authorization?: string };
  customer?: AuthenticatedCustomer;
}
