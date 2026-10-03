// E2E database guard (Jest globalSetup).
//
// Two `pnpm test:e2e` runs against one shik_menu_test destroy each other: every
// spec truncates and re-seeds in beforeAll, so the second client wipes the rows
// the first one is working with. The symptom is a *random* suite failing with
// 401/403 that reads like a business-logic bug (agent-memory id=109). This makes
// the collision explicit and immediate instead.
//
// The lock is taken inside an open transaction, so it is pinned to one pooled
// connection — an idle pooled connection may be recycled, which would silently
// drop a session-level lock. Being transaction-scoped, it is also released by
// the server itself if this process dies: a crashed run can never leave a stale
// lock behind.
//
// Cleanup lives in global-teardown-e2e.js. Jest 29 ignores the value returned
// from a global hook (@jest/core@29.7.0 runGlobalHook.js does
// `await globalModule(...)` and drops the result), so the handle is published on
// globalThis instead — both hooks run in the main process, which is what makes
// that channel work.
const fs = require('node:fs');
const path = require('node:path');
const { PrismaClient } = require('@prisma/client');

// Arbitrary constant ("SHK1" as int4). Advisory locks are per-database, so every
// run against shik_menu_test contends on this one key.
const LOCK_KEY = 1397246769;

// Symbol.for, not a string literal: setup and teardown agree on the key without
// a shared constant that can drift between the two files.
const STATE_KEY = Symbol.for('shik.e2e.dbGuard');

// Same resolution order as the specs, so the guard always locks the database the
// tests will actually use (jest globalSetup runs before @nestjs/config loads .env).
function testDatabaseUrl() {
  if (process.env.DATABASE_URL_TEST) return process.env.DATABASE_URL_TEST;
  const envFile = path.join(__dirname, '..', '.env');
  const match = fs.existsSync(envFile) &&
    fs.readFileSync(envFile, 'utf8').match(/^DATABASE_URL_TEST\s*=\s*"?([^"\n]+?)"?\s*$/m);
  return match ? match[1] : 'postgresql://postgres:postgres@localhost:5432/shik_menu_test?schema=public';
}

module.exports = async function globalSetup() {
  const prisma = new PrismaClient({ datasourceUrl: testDatabaseUrl() });

  let release;
  let onDecided;
  const decided = new Promise((resolve) => { onDecided = resolve; });

  const held = prisma.$transaction(
    async (tx) => {
      const [row] = await tx.$queryRaw`SELECT pg_try_advisory_xact_lock(${LOCK_KEY}) AS locked`;
      onDecided({ locked: row.locked });
      if (row.locked) await new Promise((resolve) => { release = resolve; });
    },
    // ponytail: 1h ceiling on the held transaction; a full run is ~2 min.
    { maxWait: 10000, timeout: 3600000 },
  );

  const cleanup = async () => {
    if (release) release(); // ends the transaction; the server releases the lock with it
    await held.catch(() => {});
    await prisma.$disconnect();
  };
  globalThis[STATE_KEY] = cleanup;

  // Publish the handle and handle `held` before awaiting: a connect or query
  // error rejects `held` without ever calling onDecided, and `await decided`
  // below would then hang globalSetup forever while the rejection surfaces as
  // an unhandled one. This settles `decided` on that path too.
  held.catch((error) => onDecided({ error }));

  const outcome = await decided;

  if (outcome.error) {
    await cleanup();
    delete globalThis[STATE_KEY];
    throw new Error(
      `[e2e] cannot reach the test database at ${testDatabaseUrl().replace(/:[^:@/]*@/, ':***@')}: ` +
        outcome.error.message,
    );
  }

  if (!outcome.locked) {
    console.error(
      '\n[e2e] shik_menu_test is already in use by another test run.\n' +
      "[e2e] Concurrent runs truncate each other's fixtures and surface as random\n" +
      '[e2e] 401/403 failures in unrelated suites. Wait for the other run to finish.\n',
    );
    await cleanup();
    delete globalThis[STATE_KEY];
    throw new Error('e2e database is busy: another test run holds the lock');
  }
};
