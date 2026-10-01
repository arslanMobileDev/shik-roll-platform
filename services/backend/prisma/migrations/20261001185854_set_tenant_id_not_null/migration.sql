/*
  Warnings:

  - Made the column `tenant_id` on table `bonus_accounts` required. This step will fail if there are existing NULL values in that column.
  - Made the column `tenant_id` on table `branches` required. This step will fail if there are existing NULL values in that column.
  - Made the column `tenant_id` on table `brands` required. This step will fail if there are existing NULL values in that column.
  - Made the column `tenant_id` on table `cooks` required. This step will fail if there are existing NULL values in that column.
  - Made the column `tenant_id` on table `couriers` required. This step will fail if there are existing NULL values in that column.
  - Made the column `tenant_id` on table `customers` required. This step will fail if there are existing NULL values in that column.
  - Made the column `tenant_id` on table `kitchen_terminals` required. This step will fail if there are existing NULL values in that column.
  - Made the column `tenant_id` on table `orders` required. This step will fail if there are existing NULL values in that column.
  - Made the column `tenant_id` on table `staff` required. This step will fail if there are existing NULL values in that column.

*/
-- AlterTable
ALTER TABLE "bonus_accounts" ALTER COLUMN "tenant_id" SET NOT NULL;

-- AlterTable
ALTER TABLE "branches" ALTER COLUMN "tenant_id" SET NOT NULL;

-- AlterTable
ALTER TABLE "brands" ALTER COLUMN "tenant_id" SET NOT NULL;

-- AlterTable
ALTER TABLE "cooks" ALTER COLUMN "tenant_id" SET NOT NULL;

-- AlterTable
ALTER TABLE "couriers" ALTER COLUMN "tenant_id" SET NOT NULL;

-- AlterTable
ALTER TABLE "customers" ALTER COLUMN "tenant_id" SET NOT NULL;

-- AlterTable
ALTER TABLE "kitchen_terminals" ALTER COLUMN "tenant_id" SET NOT NULL;

-- AlterTable
ALTER TABLE "orders" ALTER COLUMN "tenant_id" SET NOT NULL;

-- AlterTable
ALTER TABLE "staff" ALTER COLUMN "tenant_id" SET NOT NULL;
