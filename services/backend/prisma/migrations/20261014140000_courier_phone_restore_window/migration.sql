-- Courier account restore window (7 days): a deleted courier keeps its phone so
-- the number can be handed back, which breaks the plain UNIQUE that guards it.
--
-- uq_couriers_tenant_id_phone is the login key (tenant_id, phone) and used to be
-- unique across every row. From here on a deleted row holds its number for the
-- whole window, so "the number is taken" has to mean "taken by a live courier":
-- the index becomes partial and covers deleted_at IS NULL only.
--
-- Consequence, accepted deliberately (mirrors the customer flow, ADR-1625): the
-- number is NOT frozen at database level. A new courier may take it while the
-- old row still waits, and restoring then has to answer a conflict (409) rather
-- than a 500 — same shape as the customer RESTORE_CONFLICT.
--
-- Keeping the index partial is also why Courier has no @@unique([tenantId,
-- phone]) in schema.prisma. Prisma cannot express an index predicate, so
-- declaring the plain unique would make every `migrate dev` emit a phantom
-- migration that re-creates the index without the WHERE and dies with 42P07
-- ("relation already exists"). Measured 2026-10-14 on Prisma 6: with the
-- declaration removed, `migrate diff` is empty in all three directions and
-- Prisma leaves the predicate index alone — it neither creates nor drops it.
-- Do NOT "restore" the declaration to fix a diff that is not there.
--
-- Drop and create are one file on purpose: Prisma wraps a migration in a single
-- transaction on PostgreSQL (it rolls the whole run back if an operation fails),
-- so the table is never left without the constraint.
--
-- PROD: run the pre-flight SQL before `migrate deploy`.
DROP INDEX "uq_couriers_tenant_id_phone";

CREATE UNIQUE INDEX "uq_couriers_tenant_id_phone"
  ON "couriers" ("tenant_id", "phone")
  WHERE "deleted_at" IS NULL;
