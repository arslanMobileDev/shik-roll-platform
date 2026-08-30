// E2E environment bootstrap — runs before any test module is loaded
// (jest setupFiles), so the flag is in place when QueuesModule.register()
// evaluates it during AppModule import.
process.env.DISABLE_QUEUES = 'true';
