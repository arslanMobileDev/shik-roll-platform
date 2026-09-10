/**
 * Kitchen POS configuration (ADR-1618). Module-load constants follow the
 * house convention (auth.config.ts); the emulation flag is read lazily so
 * tests and the startup guard can evaluate it against the live env.
 *
 *   KITCHEN_TOKEN_TTL_SECONDS     terminal access token lifetime, default
 *                                 12 hours (one work shift; the terminal
 *                                 re-authenticates with the PIN afterwards)
 *   KITCHEN_CHANNEL_PREFIX        Redis Pub/Sub channel prefix for branch
 *                                 fan-out, default "kitchen.branch."
 *   KITCHEN_SSE_HEARTBEAT_MS      SSE heartbeat cadence, default 15 s
 *                                 (ADR: at least one heartbeat per 20 s)
 * Legacy status-simulation flags are rejected. Status ownership remains with
 * YooKassa, authenticated kitchen terminals and courier/operator endpoints.
 */
export const KITCHEN_TOKEN_TTL_SECONDS = Number(
  process.env.KITCHEN_TOKEN_TTL_SECONDS ?? 12 * 60 * 60,
);

export const KITCHEN_CHANNEL_PREFIX =
  process.env.KITCHEN_CHANNEL_PREFIX ?? 'kitchen.branch.';

export const KITCHEN_SSE_HEARTBEAT_MS = Number(
  process.env.KITCHEN_SSE_HEARTBEAT_MS ?? 15_000,
);

/**
 * Startup guard: old deployment manifests must not silently suggest that
 * status simulation still exists. The processor contains no simulator, and
 * either legacy flag is treated as a configuration error in every runtime.
 */
export function assertKitchenConfig(): void {
  if (
    process.env.KDS_STATUS_EMULATION_ENABLED === 'true' ||
    process.env.ORDER_AUTO_STATUS_ADVANCE_ENABLED === 'true'
  ) {
    throw new Error(
      'Automatic order status simulation was removed: status transitions ' +
        'belong to payment, kitchen and courier actors',
    );
  }
}
