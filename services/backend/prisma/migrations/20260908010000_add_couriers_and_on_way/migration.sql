-- AlterEnum
ALTER TYPE "OrderStatus" ADD VALUE 'ON_WAY';

-- AlterTable
ALTER TABLE "orders" ADD COLUMN     "courier_id" UUID;

-- CreateTable
CREATE TABLE "couriers" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "pin_hash" TEXT NOT NULL,
    "brand_id" UUID NOT NULL,
    "branch_id" UUID NOT NULL,
    "is_available" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "couriers_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "couriers_phone_key" ON "couriers"("phone");

-- CreateIndex
CREATE INDEX "idx_orders_courier_id" ON "orders"("courier_id");

-- AddForeignKey
ALTER TABLE "orders" ADD CONSTRAINT "fk_orders_couriers" FOREIGN KEY ("courier_id") REFERENCES "couriers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

