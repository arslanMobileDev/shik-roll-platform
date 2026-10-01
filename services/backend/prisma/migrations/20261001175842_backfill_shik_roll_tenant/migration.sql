-- Backfill: SHIK ROLL becomes tenant #1. All existing brands, branches,
-- orders, couriers, staff, cooks, terminals, customers, bonus_accounts
-- are attributed to it. Idempotent: every UPDATE has WHERE tenant_id IS NULL.

-- 1. Create tenant #1
INSERT INTO "tenants" (
  "id", "code", "name", "status", "timezone",
  "created_at", "updated_at", "version"
)
VALUES (
  gen_random_uuid(),
  'SHIK_ROLL',
  'SHIK ROLL',
  'ACTIVE',
  'Europe/Moscow',
  now(),
  now(),
  1
)
ON CONFLICT ("code") DO NOTHING;

-- 2. brands (source of truth)
UPDATE "brands"
SET "tenant_id" = (SELECT "id" FROM "tenants" WHERE "code" = 'SHIK_ROLL')
WHERE "tenant_id" IS NULL;

-- 3. branches via brand_branches
UPDATE "branches" b
SET "tenant_id" = br."tenant_id"
FROM "brand_branches" bb
JOIN "brands" br ON bb."brand_id" = br."id"
WHERE bb."branch_id" = b."id"
  AND b."tenant_id" IS NULL;

-- 3b. branches with no brand_branches row at all — legacy leftovers that step 3
-- cannot reach. Attributed to tenant #1 so no NULL survives into the future
-- NOT NULL migration.
UPDATE "branches"
SET "tenant_id" = (SELECT "id" FROM "tenants" WHERE "code" = 'SHIK_ROLL')
WHERE "tenant_id" IS NULL;

-- 4. orders via brand_id
UPDATE "orders" o
SET "tenant_id" = b."tenant_id"
FROM "brands" b
WHERE o."brand_id" = b."id"
  AND o."tenant_id" IS NULL;

-- 5. couriers via brand_id
UPDATE "couriers" c
SET "tenant_id" = b."tenant_id"
FROM "brands" b
WHERE c."brand_id" = b."id"
  AND c."tenant_id" IS NULL;

-- 6. staff via brand_id
UPDATE "staff" s
SET "tenant_id" = b."tenant_id"
FROM "brands" b
WHERE s."brand_id" = b."id"
  AND s."tenant_id" IS NULL;

-- 7. cooks via branch_id
UPDATE "cooks" c
SET "tenant_id" = b."tenant_id"
FROM "branches" b
WHERE c."branch_id" = b."id"
  AND c."tenant_id" IS NULL;

-- 8. kitchen_terminals via branch_id
UPDATE "kitchen_terminals" k
SET "tenant_id" = b."tenant_id"
FROM "branches" b
WHERE k."branch_id" = b."id"
  AND k."tenant_id" IS NULL;

-- 9. customers — all existing belong to SHIK ROLL (MVP decision)
UPDATE "customers"
SET "tenant_id" = (SELECT "id" FROM "tenants" WHERE "code" = 'SHIK_ROLL')
WHERE "tenant_id" IS NULL;

-- 10. bonus_accounts via customer_id
UPDATE "bonus_accounts" ba
SET "tenant_id" = c."tenant_id"
FROM "customers" c
WHERE ba."customer_id" = c."id"
  AND ba."tenant_id" IS NULL;
