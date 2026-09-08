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
 *   KDS_STATUS_EMULATION_ENABLED  dev harness switch: re-enables the
 *                                 SEND_TO_KITCHEN_JOB / status-timer
 *                                 auto-transitions outside production.
 *                                 Setting it in production is a configuration
 *                                 error and stops startup (see
 *                                 assertKitchenConfig).
 */
export const KITCHEN_TOKEN_TTL_SECONDS = Number(
  process.env.KITCHEN_TOKEN_TTL_SECONDS ?? 12 * 60 * 60,
);

export const KITCHEN_CHANNEL_PREFIX =
  process.env.KITCHEN_CHANNEL_PREFIX ?? 'kitchen.branch.';

export const KITCHEN_SSE_HEARTBEAT_MS = Number(
  process.env.KITCHEN_SSE_HEARTBEAT_MS ?? 15_000,
);

/** Dev-harness status emulation (timers + send-to-kitchen auto transitions). */
export function kdsStatusEmulationEnabled(): boolean {
  return process.env.KDS_STATUS_EMULATION_ENABLED === 'true';
}

/**
 * Startup guard (ADR-1618): emulation is a dev harness — enabling it in
 * production is a configuration error and must stop the boot. Called once
 * from KitchenModule init; throws before the app starts listening.
 */
export function assertKitchenConfig(): void {
  if (kdsStatusEmulationEnabled() && process.env.NODE_ENV === 'production') {
    throw new Error(
      'KDS_STATUS_EMULATION_ENABLED=true is forbidden in production: ' +
        'kitchen status transitions belong to authenticated kitchen terminals only (ADR-1618)',
    );
  }
}
