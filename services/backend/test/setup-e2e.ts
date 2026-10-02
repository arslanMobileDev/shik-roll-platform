// E2E environment bootstrap — runs before any test module is loaded
// (jest setupFiles), so the flag is in place when QueuesModule.register()
// evaluates it during AppModule import.
process.env.DISABLE_QUEUES = 'true';

// Shorten the OTP resend cooldown so e2e specs can re-authenticate the same
// phone without waiting out the production 60-second window. The resend rate
// limit itself stays active (two immediate sends are still rejected).
process.env.OTP_SEND_COOLDOWN_SECONDS = '1';

// Kitchen SSE cadence. The heartbeat itself is also the tenant-status poll
// (ADR-1622 C5), so a 15-second default would cost the suite 15 seconds per
// open stream. Read at module load, hence here rather than in the spec.
process.env.KITCHEN_SSE_HEARTBEAT_MS = '400';
