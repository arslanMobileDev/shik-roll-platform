# WI-6 — red-before-green evidence for the order-number concurrency case

Scope: **AC-2** — "the concurrency regression test exists and is demonstrably red
against the pre-fix implementation". The test it certifies is
`AC-1: 10 parallel creates for one branch all succeed with distinct numbers`
in `orders.e2e-spec.ts`, inside `describe('order number allocation (WI-5)')`.

Captured 2026-09-21 (local) in worktree `worktrees/srp-oql`, `pwd -P` verified
before every read, edit, jest invocation and `git add`.

| Item | Value |
| --- | --- |
| Test tree (patched) | `12d61178fcf7136f6fe098a70d39f73c29fb8965` |
| Unpatched baseline | `87436bec` (this worktree's start point) |
| Postgres | `shik-postgres` container, `DATABASE_URL_TEST` default `…/shik_menu_test` |
| Test runner | `pnpm exec jest --config ./test/jest-e2e.json --runInBand` |
| N (parallel requests) | **10** — M-2's fallback was not needed |
| Revert strategy | `git checkout 87436be -- <two files>`, restored with `git checkout 12d6117 -- <same two files>`; never committed |

## Red — unpatched allocator

Only the two allocation files were reverted to `git:87436bec`:

```bash
git checkout 87436be -- \
  services/backend/src/modules/orders/orders.repository.ts \
  services/backend/src/modules/orders/orders.service.ts
cd services/backend
pnpm exec jest --config ./test/jest-e2e.json --runInBand \
  test/orders.e2e-spec.ts -t "AC-1: 10 parallel"     # exit 1
```

Observed (full log: `/tmp/gc-artifacts/order-number-race/wi6-red-ac1.log`):

```
  ● Orders API (e2e) › order number allocation (WI-5) › AC-1: 10 parallel creates for one branch all succeed with distinct numbers

    expect(received).toBe(expected) // Object.is equality

    Expected: 201
    Received: 500

      at orders.e2e-spec.ts:543:28

Test Suites: 1 failed, 1 total
Tests:       1 failed, 24 skipped, 25 total

[Nest] ERROR [ExceptionsHandler] PrismaClientKnownRequestError:
Invalid `client.order.create()` invocation in
  …/worktrees/srp-oql/services/backend/src/modules/orders/orders.repository.ts:68:25
Unique constraint failed on the fields: (`order_number`)
  code: 'P2002',
  meta: { modelName: 'Order', target: [ 'order_number' ] }
```

The `uq_orders_order_number` violation is raised **8 times in that single run**
(`grep -c "Unique constraint" wi6-red-ac1.log` → 8): the old read-then-write
allocator hands the same next value to several of the 10 overlapping creates,
and the unique index is what turns the race into a failure. This is the
`P2002` signal AC-2 asks for; the assertion trips first on the resulting `500`.

## Green — patched allocator

```bash
git checkout 12d6117 -- \
  services/backend/src/modules/orders/orders.repository.ts \
  services/backend/src/modules/orders/orders.service.ts
git diff --stat HEAD -- src/modules/orders/     # empty: revert fully undone
cd services/backend
pnpm exec jest --config ./test/jest-e2e.json --runInBand \
  test/orders.e2e-spec.ts -t "AC-1: 10 parallel"     # exit 0
```

Observed (full log: `/tmp/gc-artifacts/order-number-race/wi6-green-ac1.log`):

```
    order number allocation (WI-5)
      ✓ AC-1: 10 parallel creates for one branch all succeed with distinct numbers (178 ms)

Test Suites: 1 passed, 1 total
Tests:       24 skipped, 1 passed, 25 total
```

## Full suite on the same tree

```bash
cd services/backend && pnpm exec jest --config ./test/jest-e2e.json --runInBand --verbose
```

Observed (full log: `/tmp/gc-artifacts/order-number-race/wi6-green-full-suite-verbose.log`):

```
      ✓ AC-1: 10 parallel creates for one branch all succeed with distinct numbers (356 ms)
      ✓ day rollover: each UTC day of a branch starts its own sequence at 0001 (91 ms)
      ✓ branches are independent: each branch starts at 0001 (67 ms)
      ✓ AC-9: a rejected create does not release the value it burned (224 ms)
      ✓ AC-10: deleting an order does not release its number (109 ms)

Test Suites: 3 failed, 2 passed, 5 total
Tests:       18 failed, 76 passed, 94 total
```

No WI-5 case is among the 18 failures. They are the two pre-existing classes
recorded in WI-5's summary: 8 cases call `GET /orders` / `GET /orders/:id`
anonymously against `JwtAuthGuard` (401) and 10 walk the retired
`PATCH /orders/:id/status` lifecycle that the controller answers with `410
LEGACY_STATUS_ENDPOINT_DISABLED`. Both behaviours exist at base `87436bec`,
independently of the allocation change.

## Reproducing

The capture is manual: `.github/workflows/` contains only `docs-terminology.yml`
and no CI job provides a Postgres for `DATABASE_URL_TEST` (plan OQ-4). A local
`shik-postgres` with `shik_menu_test` reachable is sufficient — the e2e specs run
`prisma migrate deploy` themselves in `beforeAll`.
