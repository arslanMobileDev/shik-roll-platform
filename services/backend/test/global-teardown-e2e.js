// E2E database guard (Jest globalTeardown) — releases the advisory lock taken by
// global-setup-e2e.js.
//
// This module exists because Jest 29 discards what a global hook returns:
// @jest/core@29.7.0 runGlobalHook.js does `await globalModule(...)` and never
// looks at the result, so a `return function teardown() {}` from globalSetup
// silently never runs. Without it, a normal run ends without committing or
// rolling back the lock transaction and without $disconnect() — the connection
// is only reclaimed when the process itself exits.
const STATE_KEY = Symbol.for('shik.e2e.dbGuard'); // same key as the setup module

module.exports = async function globalTeardown() {
  const cleanup = globalThis[STATE_KEY];
  // No handle means globalSetup threw (Jest skips teardown in that case anyway)
  // or published nothing yet — either way there is nothing to release.
  if (!cleanup) return;
  delete globalThis[STATE_KEY];
  await cleanup();
  // One line, on purpose: without it a run leaves no trace that the lock
  // transaction was closed rather than dropped when the process exited.
  console.log('[e2e] db guard: advisory lock released');
};
