-- ADR-1622 step 4c priority 2: the PIN login keys become tenant-scoped.
--
-- phone (staff, couriers, cooks) and code (kitchen_terminals) stop being
-- globally unique and become unique per tenant. This is what makes a second
-- tenant with a shared staff/courier phone physically possible.
--
-- The key-only indexes (idx_<table>_phone / idx_kitchen_terminals_code) are
-- NOT redundant: a client that does not send X-Tenant yet is resolved by
-- "who owns this key", which is a lookup on the key alone. The composite
-- unique index has tenant_id as its leading column, so it cannot serve it.
--
-- Safe to apply BEFORE the code change: this migration only weakens a
-- constraint, so it cannot fail on existing rows (unlike step 4a SET NOT NULL,
-- see Pitfall-020). The old code keeps working: Prisma renders
-- findUnique({ where: { phone } }) as `WHERE phone = $1`, which needs no index
-- to be correct.

-- DropIndex
DROP INDEX "couriers_phone_key";

-- DropIndex
DROP INDEX "staff_phone_key";

-- DropIndex
DROP INDEX "cooks_phone_key";

-- DropIndex
DROP INDEX "kitchen_terminals_code_key";

-- CreateIndex
CREATE UNIQUE INDEX "uq_couriers_tenant_id_phone" ON "couriers"("tenant_id", "phone");

-- CreateIndex
CREATE UNIQUE INDEX "uq_staff_tenant_id_phone" ON "staff"("tenant_id", "phone");

-- CreateIndex
CREATE UNIQUE INDEX "uq_cooks_tenant_id_phone" ON "cooks"("tenant_id", "phone");

-- CreateIndex
CREATE UNIQUE INDEX "uq_kitchen_terminals_tenant_id_code" ON "kitchen_terminals"("tenant_id", "code");

-- CreateIndex
CREATE INDEX "idx_couriers_phone" ON "couriers"("phone");

-- CreateIndex
CREATE INDEX "idx_staff_phone" ON "staff"("phone");

-- CreateIndex
CREATE INDEX "idx_kitchen_terminals_code" ON "kitchen_terminals"("code");
