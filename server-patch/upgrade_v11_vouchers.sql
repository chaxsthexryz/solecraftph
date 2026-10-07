-- v11: voucher codes at checkout. Safe to re-run.

CREATE TABLE IF NOT EXISTS vouchers (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code        VARCHAR(40)  NOT NULL UNIQUE,          -- stored upper-case
  type        ENUM('percent','fixed','shipping') NOT NULL,
  value       DECIMAL(10,2) NOT NULL DEFAULT 0,       -- % for percent, ₱ for fixed, unused for shipping
  min_spend   DECIMAL(10,2) NOT NULL DEFAULT 0,
  max_uses    INT UNSIGNED NULL,                      -- NULL = unlimited
  used_count  INT UNSIGNED NOT NULL DEFAULT 0,
  expires_at  DATE NULL,                              -- last valid day, NULL = never
  is_active   TINYINT(1) NOT NULL DEFAULT 1,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS voucher_code    VARCHAR(40)   NULL AFTER total_amount,
  ADD COLUMN IF NOT EXISTS discount_amount DECIMAL(10,2) NOT NULL DEFAULT 0 AFTER voucher_code;

INSERT IGNORE INTO vouchers (code, type, value, min_spend, max_uses, expires_at) VALUES
  ('WELCOME10', 'percent', 10,  0,    NULL, NULL),
  ('SOLE200',   'fixed',   200, 3000, NULL, NULL),
  ('FREESHIP',  'shipping', 0,  0,    NULL, NULL);
