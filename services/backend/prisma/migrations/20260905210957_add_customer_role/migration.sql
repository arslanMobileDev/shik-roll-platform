-- CreateEnum
CREATE TYPE "CustomerRole" AS ENUM ('CUSTOMER');

-- AlterTable
ALTER TABLE "customers" ADD COLUMN     "role" "CustomerRole" NOT NULL DEFAULT 'CUSTOMER';
