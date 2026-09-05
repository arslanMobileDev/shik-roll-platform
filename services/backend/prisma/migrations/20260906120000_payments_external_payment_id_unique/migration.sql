-- DropIndex: superseded by the unique constraint below (a unique index
-- covers the webhook lookup on external_payment_id).
DROP INDEX "idx_payments_external_payment_id";

-- CreateIndex: provider-side payment id is unique per payment attempt
-- (task contract: providerPaymentId nullable + unique; NULLs stay distinct).
CREATE UNIQUE INDEX "uq_payments_external_payment_id" ON "payments"("external_payment_id");
