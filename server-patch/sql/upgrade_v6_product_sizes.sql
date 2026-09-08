-- SoleCraftPH v6: per-size stock. Safe to re-run.
--
-- Deliberately seeds NOTHING. A shoe with stock=15 might be three US 9s and two
-- US 12s, or fifteen of one size — the database cannot know, and guessing would
-- put wrong numbers in front of customers. A product uses per-size stock only
-- once someone has entered sizes for it, and falls back to products.stock until
-- then, so the catalogue keeps working while it is converted product by product.
CREATE TABLE IF NOT EXISTS `product_sizes` (
  `id`         INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `product_id` INT(10) UNSIGNED NOT NULL,
  `size`       VARCHAR(10) NOT NULL,
  `stock`      INT(10) UNSIGNED NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_product_size` (`product_id`, `size`),
  KEY `idx_size_product` (`product_id`),
  CONSTRAINT `fk_size_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
