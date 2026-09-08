-- SoleCraftPH v3: account-backed cart + shoe size on cart/order lines.
-- Safe to re-run: every statement is guarded or idempotent.

-- 1. Shared cart. One row = one product at one size, for one account.
--    Guests stay on the PHP session cart; this table only holds signed-in bags,
--    which is what lets the website and the mobile app see the same cart.
CREATE TABLE IF NOT EXISTS `cart_items` (
  `id`         INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`    INT(10) UNSIGNED NOT NULL,
  `product_id` INT(10) UNSIGNED NOT NULL,
  `size`       VARCHAR(10) NOT NULL DEFAULT '',
  `qty`        INT(10) UNSIGNED NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT current_timestamp(),
  `updated_at` TIMESTAMP NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_cart_line` (`user_id`, `product_id`, `size`),
  KEY `idx_cart_user` (`user_id`),
  CONSTRAINT `fk_cart_user`    FOREIGN KEY (`user_id`)    REFERENCES `users` (`id`)    ON DELETE CASCADE,
  CONSTRAINT `fk_cart_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Size on order lines. The mobile app has always sent a size and the
--    server has always thrown it away — there was no column to put it in.
--    Two sizes of the same shoe are two order_items rows.
SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'order_items' AND COLUMN_NAME = 'size');
SET @sql := IF(@col = 0,
  'ALTER TABLE `order_items` ADD COLUMN `size` VARCHAR(10) NOT NULL DEFAULT '''' AFTER `product_name`',
  'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
