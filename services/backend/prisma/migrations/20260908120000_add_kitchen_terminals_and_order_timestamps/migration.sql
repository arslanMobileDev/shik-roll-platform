-- Kitchen POS (ADR-1618): branch-scoped kitchen terminals, server timestamps
-- of the kitchen-owned transitions CONFIRMED -> COOKING -> READY and the
-- kitchen audit attributes on order_status_history.

-- AlterTable
ALTER TABLE "orders"
    ADD COLUMN "confirmed_at" TIMESTAMPTZ(6),
    ADD COLUMN "cooking_started_at" TIMESTAMPTZ(6),
    ADD COLUMN "ready_at" TIMESTAMPTZ(6);

-- AlterTable
ALTER TABLE "order_status_history"
    ADD COLUMN "kitchen_terminal_id" UUID,
    ADD COLUMN "cook_id" TEXT,
    ADD COLUMN "shift_id" TEXT;

-- CreateTable
CREATE TABLE "kitchen_terminals" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "pin_hash" TEXT NOT NULL,
    "branch_id" UUID NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "kitchen_terminals_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "kitchen_terminals_code_key" ON "kitchen_terminals"("code");

-- CreateIndex
CREATE INDEX "idx_kitchen_terminals_branch_id_is_active" ON "kitchen_terminals"("branch_id", "is_active");

-- AddForeignKey
ALTER TABLE "kitchen_terminals" ADD CONSTRAINT "fk_kitchen_terminals_branches" FOREIGN KEY ("branch_id") REFERENCES "branches"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Backfill (ADR-1618): active orders get the timestamps from the first
-- matching order_status_history entry; when history is missing the fallback
-- is updated_at. The fallback is the audit marker of this migration — such
-- values approximate the status entry time and are not second-precise.
UPDATE "orders" o
SET "confirmed_at" = COALESCE((
        SELECT MIN(h."changed_at")
        FROM "order_status_history" h
        WHERE h."order_id" = o."id"
          AND h."new_status" IN ('CONFIRMED', 'COOKING', 'READY', 'ON_WAY', 'COMPLETED')
    ), o."updated_at"),
    "cooking_started_at" = CASE WHEN o."status" IN ('COOKING', 'READY') THEN COALESCE((
        SELECT MIN(h."changed_at")
        FROM "order_status_history" h
        WHERE h."order_id" = o."id"
          AND h."new_status" IN ('COOKING', 'READY', 'ON_WAY', 'COMPLETED')
    ), o."updated_at") END,
    "ready_at" = CASE WHEN o."status" = 'READY' THEN COALESCE((
        SELECT MIN(h."changed_at")
        FROM "order_status_history" h
        WHERE h."order_id" = o."id"
          AND h."new_status" IN ('READY', 'ON_WAY', 'COMPLETED')
    ), o."updated_at") END
WHERE o."status" IN ('CONFIRMED', 'COOKING', 'READY');
