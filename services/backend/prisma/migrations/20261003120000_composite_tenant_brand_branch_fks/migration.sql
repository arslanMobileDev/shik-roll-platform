-- ADR-1622 step 5: cross-tenant FK.
--
-- Before this migration a row could hold three independently valid ids. Orders
-- had single-column FKs to brands/branches but nothing tied the pair to
-- brand_branches and nothing forced brand and branch into the same tenant;
-- couriers had no FK on brand_id/branch_id at all (which is how the e2e database
-- ended up carrying a courier whose brand and branch no longer exist).
--
-- After it, brand_branches is tenant-consistent and orders/couriers prove their
-- whole (tenant_id, brand_id, branch_id) triple against it with a single FK.
--
-- PROD: run ai-brain/04-Infrastructure/prod-preflight-multitenancy.sql (БЛОК 3)
-- first. Any non-zero counter there means the DELETEs below would remove real
-- business rows — stop, clean up by hand, and only then deploy. On dev/test the
-- DELETEs are the safety net for leftovers from previous runs.

-- 1. brand_branches.tenant_id: added nullable, backfilled from the brand, then
--    made NOT NULL. brands.tenant_id is NOT NULL and brand_id already has a FK
--    to brands, so the backfill covers every row.
ALTER TABLE "brand_branches" ADD COLUMN "tenant_id" UUID;

UPDATE "brand_branches" bb
   SET "tenant_id" = b."tenant_id"
  FROM "brands" b
 WHERE b."id" = bb."brand_id";

ALTER TABLE "brand_branches" ALTER COLUMN "tenant_id" SET NOT NULL;

-- 2. Data the new constraints cannot accept. Every DELETE is scoped to rows that
--    already violate the invariant, so all three are no-ops on clean data.
--    Child rows go first: a brand_branches row must have no referrer left before
--    it can be removed.
DELETE FROM "orders" o
 WHERE NOT EXISTS (
   SELECT 1
     FROM "brand_branches" bb
     JOIN "brands" b ON b."id" = bb."brand_id"
     JOIN "branches" br ON br."id" = bb."branch_id"
    WHERE bb."tenant_id" = o."tenant_id"
      AND bb."brand_id" = o."brand_id"
      AND bb."branch_id" = o."branch_id"
      -- the link itself must survive: brand and branch of one tenant
      AND b."tenant_id" = br."tenant_id"
 );

DELETE FROM "couriers" c
 WHERE NOT EXISTS (
   SELECT 1
     FROM "brand_branches" bb
     JOIN "brands" b ON b."id" = bb."brand_id"
     JOIN "branches" br ON br."id" = bb."branch_id"
    WHERE bb."tenant_id" = c."tenant_id"
      AND bb."brand_id" = c."brand_id"
      AND bb."branch_id" = c."branch_id"
      AND b."tenant_id" = br."tenant_id"
 );

-- Brand↔branch links whose two sides belong to different tenants. They are not
-- repairable by backfill (either tenant could be "right"), so they go.
DELETE FROM "brand_branches" bb
 USING "brands" b, "branches" br
 WHERE b."id" = bb."brand_id"
   AND br."id" = bb."branch_id"
   AND b."tenant_id" <> br."tenant_id";

-- 3. FK targets.
CREATE UNIQUE INDEX "uq_brands_tenant_id_id" ON "brands"("tenant_id", "id");
CREATE UNIQUE INDEX "uq_branches_tenant_id_id" ON "branches"("tenant_id", "id");
CREATE UNIQUE INDEX "uq_brand_branches_tenant_brand_branch"
    ON "brand_branches"("tenant_id", "brand_id", "branch_id");
-- Implied by the three-column unique above (brand_id already fixes the tenant).
DROP INDEX "uq_brand_branches_brand_id_branch_id";

-- 4. Constraints.
ALTER TABLE "brand_branches" DROP CONSTRAINT "fk_brand_branches_brands";
ALTER TABLE "brand_branches" DROP CONSTRAINT "fk_brand_branches_branches";

ALTER TABLE "brand_branches" ADD CONSTRAINT "fk_brand_branches_brands"
    FOREIGN KEY ("tenant_id", "brand_id") REFERENCES "brands"("tenant_id", "id")
    ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "brand_branches" ADD CONSTRAINT "fk_brand_branches_branches"
    FOREIGN KEY ("tenant_id", "branch_id") REFERENCES "branches"("tenant_id", "id")
    ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "orders" ADD CONSTRAINT "fk_orders_brand_branches"
    FOREIGN KEY ("tenant_id", "brand_id", "branch_id")
    REFERENCES "brand_branches"("tenant_id", "brand_id", "branch_id")
    ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "couriers" ADD CONSTRAINT "fk_couriers_brand_branches"
    FOREIGN KEY ("tenant_id", "brand_id", "branch_id")
    REFERENCES "brand_branches"("tenant_id", "brand_id", "branch_id")
    ON DELETE RESTRICT ON UPDATE CASCADE;
