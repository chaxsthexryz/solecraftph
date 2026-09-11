-- =========================================================
-- SoleCraftPH — Upgrade v2
-- Adds every table/column needed for the full module list:
-- wishlists, reviews, notifications, order tracking history,
-- returns/refunds, contact/support, CMS pages, banners,
-- site settings, audit trail, and customer/admin profile fields.
--
-- Safe to run on an existing database (run once). If you are
-- installing fresh, just run sql/schema.sql followed by this file.
--
-- NOTE: there is deliberately no "USE ..." statement here. On shared
-- hosts (e.g. InfinityFree) your database is renamed with an account
-- prefix (like if0_xxxxx_solecraftph), and the hosting account isn't
-- allowed to reference any database by a different name — even its
-- own unprefixed one. Just select your actual database in phpMyAdmin
-- (or pass it on the mysql command line) before running this file,
-- and every statement below will run against whichever database is
-- already selected.
-- =========================================================

-- ---------------------------------------------------------
-- Users: profile fields + suspend/activate
-- ---------------------------------------------------------
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS full_name VARCHAR(150) NULL AFTER username,
  ADD COLUMN IF NOT EXISTS phone VARCHAR(30) NULL AFTER email,
  ADD COLUMN IF NOT EXISTS address TEXT NULL AFTER phone,
  ADD COLUMN IF NOT EXISTS status ENUM('active','suspended') NOT NULL DEFAULT 'active' AFTER role;

-- ---------------------------------------------------------
-- Products: low stock threshold (admin-configurable per product)
-- ---------------------------------------------------------
ALTER TABLE products
  ADD COLUMN IF NOT EXISTS low_stock_threshold INT UNSIGNED NOT NULL DEFAULT 5 AFTER stock;

-- ---------------------------------------------------------
-- Orders: tracking + notes + updated_at
-- ---------------------------------------------------------
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS tracking_number VARCHAR(100) NULL AFTER status,
  ADD COLUMN IF NOT EXISTS admin_notes TEXT NULL AFTER tracking_number,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER created_at;

-- ---------------------------------------------------------
-- Order status history (powers customer-facing order tracking)
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_status_log (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id   INT UNSIGNED NOT NULL,
  status     VARCHAR(30) NOT NULL,
  note       VARCHAR(255) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_statuslog_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Wishlist / Favorites
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS wishlists (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id    INT UNSIGNED NOT NULL,
  product_id INT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_wishlist (user_id, product_id),
  CONSTRAINT fk_wishlist_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_wishlist_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Product reviews & ratings
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS product_reviews (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_id INT UNSIGNED NOT NULL,
  user_id    INT UNSIGNED NOT NULL,
  rating     TINYINT UNSIGNED NOT NULL,
  comment    TEXT NULL,
  status     ENUM('pending','approved','rejected') NOT NULL DEFAULT 'approved',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_review_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
  CONSTRAINT fk_review_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT chk_rating CHECK (rating BETWEEN 1 AND 5)
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Notifications (customer order/promo alerts + admin alerts)
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id    INT UNSIGNED NULL,         -- NULL = broadcast (e.g. shown to all admins)
  audience   ENUM('customer','admin') NOT NULL DEFAULT 'customer',
  title      VARCHAR(150) NOT NULL,
  message    VARCHAR(500) NOT NULL,
  is_read    TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Returns / Refunds
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS returns (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id    INT UNSIGNED NOT NULL,
  user_id     INT UNSIGNED NULL,
  reason      VARCHAR(150) NOT NULL,
  details     TEXT NULL,
  status      ENUM('requested','approved','rejected','refunded') NOT NULL DEFAULT 'requested',
  admin_notes TEXT NULL,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_return_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  CONSTRAINT fk_return_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Contact / Support messages
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS contact_messages (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name       VARCHAR(150) NOT NULL,
  email      VARCHAR(150) NOT NULL,
  subject    VARCHAR(200) NOT NULL,
  message    TEXT NOT NULL,
  status     ENUM('new','read','resolved') NOT NULL DEFAULT 'new',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- CMS: static pages (About Us, FAQ, Privacy Policy, ...)
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms_pages (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  slug       VARCHAR(80) NOT NULL UNIQUE,
  title      VARCHAR(150) NOT NULL,
  content    LONGTEXT NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

INSERT INTO cms_pages (slug, title, content) VALUES
('about', 'About Us', 'SoleCraftPH is a footwear storefront dedicated to authentic, fairly-priced shoes for every Filipino.\n\nEdit this page any time from the admin panel (Content > Pages).'),
('faq', 'FAQs', 'Q: How long does delivery take?\nA: 3-5 business days nationwide.\n\nQ: Do you accept COD?\nA: Yes, Cash on Delivery is available nationwide.\n\nEdit this page any time from the admin panel (Content > Pages).'),
('privacy', 'Privacy Policy', 'We respect your privacy. Your personal information is only used to process your orders and is never sold to third parties.\n\nEdit this page any time from the admin panel (Content > Pages).')
ON DUPLICATE KEY UPDATE slug = slug;

-- ---------------------------------------------------------
-- Homepage banners / promotions (CMS-managed)
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS banners (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  title      VARCHAR(150) NOT NULL,
  subtitle   VARCHAR(255) NULL,
  link_url   VARCHAR(255) NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_active  TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Site-wide settings (key/value)
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS settings (
  setting_key   VARCHAR(60) PRIMARY KEY,
  setting_value TEXT NULL
) ENGINE=InnoDB;

INSERT INTO settings (setting_key, setting_value) VALUES
('currency_symbol', '₱'),
('shipping_fee', '150'),
('free_shipping_threshold', '2000'),
('payment_cod_enabled', '1'),
('payment_gcash_enabled', '1'),
('payment_card_enabled', '1'),
('store_name', 'SoleCraftPH'),
('support_email', 'support@solecraftph.local'),
('support_phone', '0917-000-0000'),
('low_stock_default_threshold', '5')
ON DUPLICATE KEY UPDATE setting_key = setting_key;

-- ---------------------------------------------------------
-- Admin audit trail
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_log (
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  admin_id       INT UNSIGNED NULL,
  admin_username VARCHAR(60) NULL,
  action         VARCHAR(100) NOT NULL,
  details        VARCHAR(500) NULL,
  created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_audit_admin FOREIGN KEY (admin_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;
