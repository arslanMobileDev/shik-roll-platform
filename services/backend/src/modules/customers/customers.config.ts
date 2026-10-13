/**
 * Customer account lifecycle (Apple-required self-service deletion).
 *
 * Both values are product decisions recorded in the deletion handoff, not
 * environment tuning — they are constants, not env vars, so dev, test and
 * production cannot drift apart on the freeze window.
 */

/**
 * How long a deleted customer's phone stays frozen before re-registration on
 * that number opens. During the window a login on the frozen number is offered
 * a restore instead of getting a fresh (empty) account.
 */
export const PHONE_RELEASE_WINDOW_DAYS = 30;

/**
 * Lifetime of the one-shot tokens that carry the two account flows: the
 * deletion confirmation token and the restore token. Short on purpose — a
 * leaked token is a one-shot state change on one account.
 */
export const ACCOUNT_FLOW_TOKEN_TTL_SECONDS = 5 * 60;

/** JWT `type` claim values; neither ever passes the access-token check. */
export const DELETION_TOKEN_TYPE = 'delete';
export const RESTORE_TOKEN_TYPE = 'restore';

/** Stored in deleted_reason. Server-side constant only, never client input. */
export const DeletionReason = {
  USER_REQUEST: 'USER_REQUEST',
} as const;

/**
 * Orders that block deletion: everything the kitchen or a courier is still
 * working on. PENDING_PAYMENT is deliberately absent — an abandoned unpaid
 * checkout would otherwise block the account's deletion forever.
 */
export const BLOCKING_ORDER_STATUSES = [
  'NEW',
  'CONFIRMED',
  'COOKING',
  'READY',
  'ON_WAY',
] as const;
