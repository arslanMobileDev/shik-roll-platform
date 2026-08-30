-- CreateEnum
CREATE TYPE "ProductStatus" AS ENUM ('DRAFT', 'PUBLISHED', 'HIDDEN', 'ARCHIVED');

-- AlterEnum
BEGIN;
CREATE TYPE "MenuStatus_new" AS ENUM ('DRAFT', 'PUBLISHED', 'UNPUBLISHED');
ALTER TABLE "public"."menus" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "menus" ALTER COLUMN "status" TYPE "MenuStatus_new" USING ("status"::text::"MenuStatus_new");
ALTER TYPE "MenuStatus" RENAME TO "MenuStatus_old";
ALTER TYPE "MenuStatus_new" RENAME TO "MenuStatus";
DROP TYPE "public"."MenuStatus_old";
ALTER TABLE "menus" ALTER COLUMN "status" SET DEFAULT 'DRAFT';
COMMIT;

-- DropForeignKey
ALTER TABLE "products" DROP CONSTRAINT "fk_products_menu_categories";

-- DropIndex
DROP INDEX "idx_products_is_active";

-- AlterTable
ALTER TABLE "menus" ADD COLUMN     "current_version" INTEGER,
ADD COLUMN     "draft_updated_at" TIMESTAMPTZ(6),
ADD COLUMN     "unpublished_at" TIMESTAMPTZ(6);

-- AlterTable
ALTER TABLE "products"
ADD COLUMN     "archived_at" TIMESTAMPTZ(6),
ADD COLUMN     "hidden_at" TIMESTAMPTZ(6),
ADD COLUMN     "is_new" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "is_popular" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "published_at" TIMESTAMPTZ(6),
ADD COLUMN     "sort_order" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "source_key" TEXT;

-- Backfill lifecycle status from the legacy is_active flag (DB-607 v1.2.0:
-- products.status is the only lifecycle field), then drop the flag.
ALTER TABLE "products" ADD COLUMN "status" "ProductStatus" NOT NULL DEFAULT 'DRAFT';
UPDATE "products" SET "status" = 'PUBLISHED', "published_at" = now() WHERE "is_active";
ALTER TABLE "products" DROP COLUMN "is_active";

-- Backfill menu_id from the product's category, then enforce NOT NULL and the FK.
ALTER TABLE "products" ADD COLUMN "menu_id" UUID;
UPDATE "products" p SET "menu_id" = c."menu_id" FROM "menu_categories" c WHERE c."id" = p."category_id";
ALTER TABLE "products" ALTER COLUMN "menu_id" SET NOT NULL;
ALTER TABLE "products" ADD CONSTRAINT "fk_products_menus" FOREIGN KEY ("menu_id") REFERENCES "menus"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- CreateIndex
CREATE UNIQUE INDEX "uq_menu_categories_id_menu_id" ON "menu_categories"("id", "menu_id");

-- CreateIndex
CREATE INDEX "idx_products_menu_id" ON "products"("menu_id");

-- CreateIndex
CREATE INDEX "idx_products_status" ON "products"("status");

-- CreateIndex
CREATE INDEX "idx_products_source_key" ON "products"("source_key");

-- CreateIndex
CREATE UNIQUE INDEX "uq_products_menu_id_source_key" ON "products"("menu_id", "source_key");

-- AddForeignKey
ALTER TABLE "products" ADD CONSTRAINT "fk_products_menu_categories" FOREIGN KEY ("category_id", "menu_id") REFERENCES "menu_categories"("id", "menu_id") ON DELETE RESTRICT ON UPDATE CASCADE;

