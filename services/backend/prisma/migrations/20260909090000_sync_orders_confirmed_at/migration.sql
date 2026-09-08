-- Reconcile the Prisma migration history with the confirmed_at column that
-- was applied manually to the local/production database as a hotfix.
-- IF NOT EXISTS keeps this migration safe for databases that already contain
-- the hotfix while still creating the column on clean deployments.
ALTER TABLE "orders"
ADD COLUMN IF NOT EXISTS "confirmed_at" TIMESTAMPTZ(6);
