-- CreateTable
CREATE TABLE "order_sequences" (
    "branch_id" UUID NOT NULL,
    "day" DATE NOT NULL,
    "last_value" INTEGER NOT NULL DEFAULT 0,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "pk_order_sequences" PRIMARY KEY ("branch_id", "day")
);

-- AddForeignKey
ALTER TABLE "order_sequences"
  ADD CONSTRAINT "fk_order_sequences_branches"
  FOREIGN KEY ("branch_id") REFERENCES "branches"("id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

-- Seed from numbers already issued, so a populated database does not
-- reissue a number that is already on an order.
INSERT INTO "order_sequences" ("branch_id", "day", "last_value", "updated_at")
SELECT o."branch_id",
       to_date(split_part(o."order_number", '-', 2), 'YYYYMMDD'),
       MAX(split_part(o."order_number", '-', 3)::int),
       now()
FROM "orders" o
WHERE o."order_number" ~ '^[A-Z0-9]{4}-[0-9]{8}-[0-9]+$'
GROUP BY o."branch_id", to_date(split_part(o."order_number", '-', 2), 'YYYYMMDD')
ON CONFLICT ("branch_id", "day") DO NOTHING;
