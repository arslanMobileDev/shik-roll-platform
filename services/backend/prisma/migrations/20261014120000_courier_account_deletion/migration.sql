-- Courier self-service account deletion (Apple 5.1.1(v)): soft delete with
-- anonymization, mirroring the customer flow one migration back.
--
-- Couriers are never hard-deleted. Orders reference them with ON DELETE SET
-- NULL, so a real DELETE would not fail — it would silently strip courier_id
-- from the whole delivery history the restaurant keeps for payroll and
-- disputes. The row therefore stays; the personal fields (name, phone, PIN)
-- are erased and deleted_at records when.
--
-- phone becomes NULL rather than a 'deleted:<uuid>' tombstone, for the two
-- reasons spelled out in 20261013120000_customer_account_deletion:
--   * Postgres treats NULLs as distinct in uq_couriers_tenant_id_phone, so the
--     number is released for a new courier on the same shift either way;
--   * the tombstone would leak. courierSelect in staff-couriers.controller.ts
--     returns phone to the staff panel, which would render 'deleted:<uuid>' as
--     the courier's contact.
-- Deleting the phone also removes the login key: a NULL never matches
-- authenticateByPin, which looks the row up by phone.
--
-- No index on deleted_at: the customer migration needed one for its
-- phone-release job, and couriers have no such job (no restore window).
-- No deleted_reason either — the only path is USER_REQUEST, so the column
-- would hold one value forever.

ALTER TABLE "couriers" ALTER COLUMN "phone" DROP NOT NULL;
ALTER TABLE "couriers" ADD COLUMN "deleted_at" TIMESTAMPTZ(6);
