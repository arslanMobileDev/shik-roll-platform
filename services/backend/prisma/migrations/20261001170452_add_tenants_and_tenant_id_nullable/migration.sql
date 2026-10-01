-- AlterTable
ALTER TABLE "bonus_accounts" ADD COLUMN     "tenant_id" UUID;

-- AlterTable
ALTER TABLE "branches" ADD COLUMN     "tenant_id" UUID;

-- AlterTable
ALTER TABLE "brands" ADD COLUMN     "tenant_id" UUID;

-- AlterTable
ALTER TABLE "cooks" ADD COLUMN     "tenant_id" UUID;

-- AlterTable
ALTER TABLE "couriers" ADD COLUMN     "tenant_id" UUID;

-- AlterTable
ALTER TABLE "customers" ADD COLUMN     "tenant_id" UUID;

-- AlterTable
ALTER TABLE "kitchen_terminals" ADD COLUMN     "tenant_id" UUID;

-- AlterTable
ALTER TABLE "orders" ADD COLUMN     "tenant_id" UUID;

-- AlterTable
ALTER TABLE "staff" ADD COLUMN     "tenant_id" UUID;

-- CreateTable
CREATE TABLE "tenants" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "timezone" TEXT NOT NULL DEFAULT 'Europe/Moscow',
    "contact_email" TEXT,
    "contact_phone" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "created_by" UUID,
    "updated_by" UUID,
    "version" INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT "tenants_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tenant_api_keys" (
    "id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "prefix" TEXT NOT NULL,
    "secret_hash" TEXT NOT NULL,
    "scopes" TEXT[] DEFAULT ARRAY['read']::TEXT[],
    "last_used_at" TIMESTAMPTZ(6),
    "expires_at" TIMESTAMPTZ(6),
    "revoked_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" UUID,

    CONSTRAINT "tenant_api_keys_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "courier_invites" (
    "id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "brand_id" UUID NOT NULL,
    "branch_id" UUID NOT NULL,
    "code_hash" TEXT NOT NULL,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "used_at" TIMESTAMPTZ(6),
    "used_by_courier_id" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" UUID,

    CONSTRAINT "courier_invites_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "idx_tenants_status" ON "tenants"("status");

-- CreateIndex
CREATE UNIQUE INDEX "uq_tenants_code" ON "tenants"("code");

-- CreateIndex
CREATE INDEX "idx_tenant_api_keys_tenant_id_revoked_at" ON "tenant_api_keys"("tenant_id", "revoked_at");

-- CreateIndex
CREATE UNIQUE INDEX "uq_tenant_api_keys_prefix" ON "tenant_api_keys"("prefix");

-- CreateIndex
CREATE INDEX "idx_courier_invites_tenant_id_expires_at" ON "courier_invites"("tenant_id", "expires_at");

-- CreateIndex
CREATE INDEX "idx_courier_invites_branch_id" ON "courier_invites"("branch_id");

-- CreateIndex
CREATE UNIQUE INDEX "uq_courier_invites_code_hash" ON "courier_invites"("code_hash");

-- CreateIndex
CREATE INDEX "idx_bonus_accounts_tenant_id" ON "bonus_accounts"("tenant_id");

-- CreateIndex
CREATE INDEX "idx_branches_tenant_id" ON "branches"("tenant_id");

-- CreateIndex
CREATE INDEX "idx_brands_tenant_id" ON "brands"("tenant_id");

-- CreateIndex
CREATE INDEX "idx_cooks_tenant_id" ON "cooks"("tenant_id");

-- CreateIndex
CREATE INDEX "idx_couriers_tenant_id" ON "couriers"("tenant_id");

-- CreateIndex
CREATE INDEX "idx_customers_tenant_id" ON "customers"("tenant_id");

-- CreateIndex
CREATE INDEX "idx_kitchen_terminals_tenant_id" ON "kitchen_terminals"("tenant_id");

-- CreateIndex
CREATE INDEX "idx_orders_tenant_id" ON "orders"("tenant_id");

-- CreateIndex
CREATE INDEX "idx_staff_tenant_id" ON "staff"("tenant_id");

-- AddForeignKey
ALTER TABLE "tenant_api_keys" ADD CONSTRAINT "fk_tenant_api_keys_tenants" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "courier_invites" ADD CONSTRAINT "fk_courier_invites_tenants" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "courier_invites" ADD CONSTRAINT "fk_courier_invites_brands" FOREIGN KEY ("brand_id") REFERENCES "brands"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "courier_invites" ADD CONSTRAINT "fk_courier_invites_branches" FOREIGN KEY ("branch_id") REFERENCES "branches"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "brands" ADD CONSTRAINT "fk_brands_tenants" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "branches" ADD CONSTRAINT "fk_branches_tenants" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "orders" ADD CONSTRAINT "fk_orders_tenants" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customers" ADD CONSTRAINT "fk_customers_tenants" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "couriers" ADD CONSTRAINT "fk_couriers_tenants" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kitchen_terminals" ADD CONSTRAINT "fk_kitchen_terminals_tenants" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bonus_accounts" ADD CONSTRAINT "fk_bonus_accounts_tenants" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "staff" ADD CONSTRAINT "fk_staff_tenants" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cooks" ADD CONSTRAINT "fk_cooks_tenants" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
