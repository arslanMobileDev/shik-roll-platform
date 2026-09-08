-- CreateEnum
CREATE TYPE "BonusTransactionType" AS ENUM ('EARN', 'SPEND', 'EXPIRE', 'REFUND');

-- CreateEnum
CREATE TYPE "PromotionCampaignStatus" AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'ENDED');

-- AlterTable
ALTER TABLE "orders" ADD COLUMN     "applied_bonus_points" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "bonus_discount_amount" DECIMAL(10,2) NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "bonus_accounts" (
    "id" UUID NOT NULL,
    "customer_id" UUID NOT NULL,
    "balance" INTEGER NOT NULL DEFAULT 0,
    "cashback_rate" DECIMAL(5,2) NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "bonus_accounts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "bonus_transactions" (
    "id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "order_id" UUID,
    "type" "BonusTransactionType" NOT NULL,
    "points" INTEGER NOT NULL,
    "balance_after" INTEGER NOT NULL,
    "idempotency_key" TEXT NOT NULL,
    "expires_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "bonus_transactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "promotion_campaigns" (
    "id" UUID NOT NULL,
    "brand_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "banner_url" TEXT NOT NULL,
    "action_url" TEXT,
    "status" "PromotionCampaignStatus" NOT NULL DEFAULT 'DRAFT',
    "priority" INTEGER NOT NULL DEFAULT 0,
    "starts_at" TIMESTAMPTZ(6) NOT NULL,
    "ends_at" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "promotion_campaigns_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "bonus_accounts_customer_id_key" ON "bonus_accounts"("customer_id");

-- CreateIndex
CREATE UNIQUE INDEX "bonus_transactions_idempotency_key_key" ON "bonus_transactions"("idempotency_key");

-- CreateIndex
CREATE INDEX "idx_bonus_transactions_account_id_created_at" ON "bonus_transactions"("account_id", "created_at");

-- CreateIndex
CREATE INDEX "idx_bonus_transactions_order_id" ON "bonus_transactions"("order_id");

-- CreateIndex
CREATE INDEX "idx_promotion_campaigns_feed" ON "promotion_campaigns"("brand_id", "status", "starts_at", "ends_at");

-- AddForeignKey
ALTER TABLE "bonus_accounts" ADD CONSTRAINT "fk_bonus_accounts_customers" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bonus_transactions" ADD CONSTRAINT "fk_bonus_transactions_bonus_accounts" FOREIGN KEY ("account_id") REFERENCES "bonus_accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bonus_transactions" ADD CONSTRAINT "fk_bonus_transactions_orders" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "promotion_campaigns" ADD CONSTRAINT "fk_promotion_campaigns_brands" FOREIGN KEY ("brand_id") REFERENCES "brands"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- CHECK constraints (ADR-1614): the balance projection never goes negative,
-- cashback rate is a percentage, ledger rows always move points and a
-- campaign window is non-empty.
ALTER TABLE "bonus_accounts" ADD CONSTRAINT "chk_bonus_accounts_balance_non_negative" CHECK ("balance" >= 0);
ALTER TABLE "bonus_accounts" ADD CONSTRAINT "chk_bonus_accounts_cashback_rate_range" CHECK ("cashback_rate" BETWEEN 0 AND 100);
ALTER TABLE "bonus_transactions" ADD CONSTRAINT "chk_bonus_transactions_points_non_zero" CHECK ("points" <> 0);
ALTER TABLE "promotion_campaigns" ADD CONSTRAINT "chk_promotion_campaigns_window" CHECK ("ends_at" > "starts_at");
