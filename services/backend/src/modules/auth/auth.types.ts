import { CustomerRole } from '@prisma/client';

/** JWT payload of the guest access/refresh tokens. */
export interface CustomerTokenPayload {
  /** Customer id (customers.id) */
  sub: string;
  phone: string;
  /** Present on tokens issued after the role column landed. */
  role?: CustomerRole;
  type: 'access' | 'refresh';
}

/** Guest identity attached to the request by the JWT guards. */
export interface AuthenticatedCustomer {
  id: string;
  phone: string;
  role: CustomerRole;
}

/** Minimal request shape used by the guards (avoids express type coupling). */
export interface RequestWithCustomer {
  headers: { authorization?: string };
  customer?: AuthenticatedCustomer;
}
