-- Where the order actually goes, when the customer pinned it. Kept on the
-- order rather than read back from `addresses`, because the address book is
-- the customer's to edit and an order must keep saying where it was sent.
ALTER TABLE orders
    ADD COLUMN latitude  DECIMAL(10, 7) NULL AFTER customer_address,
    ADD COLUMN longitude DECIMAL(10, 7) NULL AFTER latitude;
