-- Customer self-service account deletion (Apple requirement): soft delete with
-- anonymization, bonus expiry and a 30-day phone freeze.
--
-- Customers are never hard-deleted — orders.customer_id and
-- bonus_accounts.customer_id are ON DELETE RESTRICT, so the row must survive as
-- the anchor of the financial history. Deletion therefore means: the row stays,
-- the personal data (phone, name, email) is erased, and deleted_at records when.
--
-- phone becomes nullable instead of carrying a fabricated tombstone such as
-- 'deleted:<uuid>'. Postgres treats NULLs as distinct in a unique index, so the
-- slot is released just the same — and unlike a tombstone, NULL cannot leak:
-- couriers.service.ts hands order.customer.phone to the courier across the full
-- order history, which would have shown every courier the tombstone string.
-- The original number is parked in phone_pending_release for the restore window.
--
-- PROD: run ai-brain/04-Infrastructure/prod-preflight-account-deletion.sql first.

-- 1. phone: unique sign-in identifier, no longer required once anonymized.
--    uq_customers_phone is kept as-is: it now indexes (phone) with NULLs
--    treated as distinct, which is exactly the released-slot semantics needed.
ALTER TABLE "customers" ALTER COLUMN "phone" DROP NOT NULL;

-- 2. Deletion markers. deleted_reason is filled from a server-side constant
--    only, so the anonymized row can never carry caller-supplied PII.
ALTER TABLE "customers" ADD COLUMN "deleted_at" TIMESTAMPTZ(6);
ALTER TABLE "customers" ADD COLUMN "deleted_reason" TEXT;

-- 3. The frozen number, returned to phone on restore.
--    Deliberately NOT unique: a partial unique index over the freeze window is
--    impossible (now() is not IMMUTABLE, so Postgres rejects it in a predicate).
--    Two frozen rows on one number are reachable in principle; the live set is
--    still protected by uq_customers_phone, and the frozen lookup takes the
--    newest row via findFirst(orderBy: deletedAt desc).
ALTER TABLE "customers" ADD COLUMN "phone_pending_release" TEXT;

-- 4. Index for the release job, which scans deleted rows by deleted_at.
--    Plain, not partial: Prisma cannot express an index predicate, so a partial
--    index here would drift against schema.prisma on the next migrate diff.
--    No index on phone_pending_release: the frozen set is small.
CREATE INDEX "idx_customers_deleted_at" ON "customers"("deleted_at");
