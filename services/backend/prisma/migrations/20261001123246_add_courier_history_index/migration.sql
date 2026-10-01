-- CreateIndex
CREATE INDEX "idx_orders_courier_completed" ON "orders"("courier_id", "completed_at");
