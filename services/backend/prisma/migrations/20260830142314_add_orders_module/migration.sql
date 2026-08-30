-- CreateEnum
CREATE TYPE "OrderType" AS ENUM ('DINE_IN', 'TAKEAWAY', 'DELIVERY');

-- CreateEnum
CREATE TYPE "OrderStatus" AS ENUM ('NEW', 'CONFIRMED', 'COOKING', 'READY', 'COMPLETED', 'CANCELLED');

-- CreateTable
CREATE TABLE "orders" (
    "id" UUID NOT NULL,
    "order_number" TEXT NOT NULL,
    "status" "OrderStatus" NOT NULL DEFAULT 'NEW',
    "type" "OrderType" NOT NULL,
    "brand_id" UUID NOT NULL,
    "branch_id" UUID NOT NULL,
    "table_number" TEXT,
    "delivery_address" TEXT,
    "comment" TEXT,
    "subtotal_amount" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "total_amount" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "currency" TEXT NOT NULL DEFAULT 'RUB',
    "estimated_ready_at" TIMESTAMPTZ(6),
    "completed_at" TIMESTAMPTZ(6),
    "cancelled_at" TIMESTAMPTZ(6),
    "cancel_reason" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "created_by" UUID,
    "updated_by" UUID,
    "version" INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT "orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "order_items" (
    "id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL,
    "unit_price" DECIMAL(10,2) NOT NULL,
    "total_amount" DECIMAL(10,2) NOT NULL,
    "comment" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "order_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "order_item_modifiers" (
    "id" UUID NOT NULL,
    "order_item_id" UUID NOT NULL,
    "modifier_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "price_delta" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "order_item_modifiers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "order_status_history" (
    "id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "previous_status" "OrderStatus" NOT NULL,
    "new_status" "OrderStatus" NOT NULL,
    "changed_by" UUID,
    "reason" TEXT,
    "changed_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "order_status_history_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "idx_orders_brand_id" ON "orders"("brand_id");

-- CreateIndex
CREATE INDEX "idx_orders_branch_id" ON "orders"("branch_id");

-- CreateIndex
CREATE INDEX "idx_orders_status" ON "orders"("status");

-- CreateIndex
CREATE INDEX "idx_orders_created_at" ON "orders"("created_at");

-- CreateIndex
CREATE UNIQUE INDEX "uq_orders_order_number" ON "orders"("order_number");

-- CreateIndex
CREATE INDEX "idx_order_items_order_id" ON "order_items"("order_id");

-- CreateIndex
CREATE INDEX "idx_order_items_product_id" ON "order_items"("product_id");

-- CreateIndex
CREATE INDEX "idx_order_item_modifiers_order_item_id" ON "order_item_modifiers"("order_item_id");

-- CreateIndex
CREATE INDEX "idx_order_item_modifiers_modifier_id" ON "order_item_modifiers"("modifier_id");

-- CreateIndex
CREATE INDEX "idx_order_status_history_order_id" ON "order_status_history"("order_id");

-- AddForeignKey
ALTER TABLE "orders" ADD CONSTRAINT "fk_orders_brands" FOREIGN KEY ("brand_id") REFERENCES "brands"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "orders" ADD CONSTRAINT "fk_orders_branches" FOREIGN KEY ("branch_id") REFERENCES "branches"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_items" ADD CONSTRAINT "fk_order_items_orders" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_items" ADD CONSTRAINT "fk_order_items_products" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_item_modifiers" ADD CONSTRAINT "fk_order_item_modifiers_order_items" FOREIGN KEY ("order_item_id") REFERENCES "order_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_item_modifiers" ADD CONSTRAINT "fk_order_item_modifiers_modifiers" FOREIGN KEY ("modifier_id") REFERENCES "modifiers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_status_history" ADD CONSTRAINT "fk_order_status_history_orders" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;
