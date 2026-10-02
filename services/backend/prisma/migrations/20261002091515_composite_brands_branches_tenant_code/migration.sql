-- DropIndex
DROP INDEX "uq_branches_code";

-- DropIndex
DROP INDEX "uq_brands_code";

-- CreateIndex
CREATE UNIQUE INDEX "uq_branches_tenant_id_code" ON "branches"("tenant_id", "code");

-- CreateIndex
CREATE UNIQUE INDEX "uq_brands_tenant_id_code" ON "brands"("tenant_id", "code");
