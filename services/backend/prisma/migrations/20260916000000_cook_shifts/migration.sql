BEGIN;
LOCK TABLE "order_status_history" IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM order_status_history WHERE cook_id IS NOT NULL OR shift_id IS NOT NULL) THEN
    RAISE EXCEPTION 'cook_shifts: legacy cook/shift attribution exists. Reconcile it before migration; no audit data was changed.';
  END IF;
END $$;
ALTER TABLE order_status_history ALTER COLUMN cook_id TYPE UUID USING cook_id::uuid,
  ALTER COLUMN shift_id TYPE UUID USING shift_id::uuid;
-- CreateTable
CREATE TABLE "cooks" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "pin_hash" TEXT NOT NULL,
    "branch_id" UUID NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "cooks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cook_shifts" (
    "id" UUID NOT NULL,
    "cook_id" UUID NOT NULL,
    "terminal_id" UUID NOT NULL,
    "branch_id" UUID NOT NULL,
    "started_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ended_at" TIMESTAMPTZ(6),
    "ended_reason" TEXT,

    CONSTRAINT "cook_shifts_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "cooks_phone_key" ON "cooks"("phone");

-- CreateIndex
CREATE INDEX "cooks_branch_id_is_active_idx" ON "cooks"("branch_id", "is_active");

-- CreateIndex
CREATE INDEX "cook_shifts_cook_id_started_at_idx" ON "cook_shifts"("cook_id", "started_at");

-- CreateIndex
CREATE INDEX "cook_shifts_branch_id_ended_at_idx" ON "cook_shifts"("branch_id", "ended_at");

-- AddForeignKey
ALTER TABLE "order_status_history" ADD CONSTRAINT "order_status_history_cook_id_fkey" FOREIGN KEY ("cook_id") REFERENCES "cooks"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_status_history" ADD CONSTRAINT "order_status_history_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "cook_shifts"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cooks" ADD CONSTRAINT "cooks_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "branches"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cook_shifts" ADD CONSTRAINT "cook_shifts_cook_id_fkey" FOREIGN KEY ("cook_id") REFERENCES "cooks"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cook_shifts" ADD CONSTRAINT "cook_shifts_terminal_id_fkey" FOREIGN KEY ("terminal_id") REFERENCES "kitchen_terminals"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cook_shifts" ADD CONSTRAINT "cook_shifts_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "branches"("id") ON DELETE RESTRICT ON UPDATE CASCADE;


CREATE UNIQUE INDEX cook_shifts_one_open_cook ON cook_shifts(cook_id) WHERE ended_at IS NULL;
CREATE UNIQUE INDEX cook_shifts_one_open_terminal ON cook_shifts(terminal_id) WHERE ended_at IS NULL;
ALTER TABLE cook_shifts ADD CONSTRAINT cook_shifts_time_order CHECK (ended_at IS NULL OR ended_at >= started_at);
COMMIT;
