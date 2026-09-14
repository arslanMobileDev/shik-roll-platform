import { StaffRole } from '@prisma/client';

/** Payload carried inside a signed staff access token. */
export interface StaffTokenPayload {
  sub: string;        // staff.id (uuid)
  phone: string;
  role: StaffRole;
  brandId: string;
  type: 'access';
}

/** Request after StaffJwtAuthGuard attaches the verified actor. */
export interface AuthenticatedStaff {
  id: string;
  phone: string;
  role: StaffRole;
  brandId: string;
}

/** Minimal request shape used by the staff guard (avoids express type coupling). */
export interface RequestWithStaff {
  headers: { authorization?: string };
  staff?: AuthenticatedStaff;
}
