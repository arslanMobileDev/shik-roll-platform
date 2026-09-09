-- CreateEnum
CREATE TYPE "PaymentMethod" AS ENUM ('ONLINE', 'ON_DELIVERY');

-- AlterEnum
ALTER TYPE "OrderStatus" ADD VALUE 'PENDING_PAYMENT';

-- AlterTable
ALTER TABLE "orders" ADD COLUMN     "payment_method" "PaymentMethod" NOT NULL DEFAULT 'ON_DELIVERY';
