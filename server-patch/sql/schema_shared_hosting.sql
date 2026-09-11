-- =========================================================
-- SoleCraftPH Database Schema — Shared Hosting version
-- (InfinityFree, and similar hosts where you don't have
-- CREATE DATABASE / CREATE USER / GRANT privileges)
--
-- Difference from sql/schema.sql: no CREATE DATABASE, USE,
-- CREATE USER, GRANT, or FLUSH PRIVILEGES statements — your
-- host already created the database and DB user for you.
-- Before running this file, open your actual database in
-- phpMyAdmin first (e.g. if0_42563506_solecraftph) so it's
-- selected, then run this on the SQL tab or via Import.
-- =========================================================

-- ---------------------------------------------------------
-- Users (Authentication) - Admin Side + Customer accounts
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  username      VARCHAR(60)  NOT NULL UNIQUE,
  email         VARCHAR(150) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role          ENUM('admin','customer') NOT NULL DEFAULT 'customer',
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Default admin account -> username: admin / password: Admin@123
-- (bcrypt hash, verified compatible with PHP's password_verify())
-- CHANGE THIS PASSWORD after first login in a real deployment.
INSERT INTO users (username, email, password_hash, role)
VALUES ('admin', 'admin@solecraftph.local',
'$2b$10$JIDh.jMUXXr0KRb6iTriouDEUgM58z7CbdC86AbFWfDBek6PnR7vq', 'admin')
ON DUPLICATE KEY UPDATE username = username;

-- ---------------------------------------------------------
-- Products (Product Service / Inventory)
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS products (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(150) NOT NULL,
  category    VARCHAR(100) NOT NULL,      -- Main category, e.g. "Athletic & Performance Footwear"
  subcategory VARCHAR(100) NULL,          -- Subcategory, e.g. "Road Running Shoes"
  description TEXT NULL,
  price       DECIMAL(10,2) NOT NULL,
  sale_price  DECIMAL(10,2) NULL,         -- NULL = not on sale
  stock       INT UNSIGNED NOT NULL DEFAULT 0,
  badge       VARCHAR(40)  NULL,          -- e.g. "New", "Best Seller"
  image       VARCHAR(255) NULL,          -- uploaded image filename
  is_active   TINYINT(1) NOT NULL DEFAULT 1,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FULLTEXT KEY ft_search (name, category, subcategory, description)
) ENGINE=InnoDB;

-- If you're upgrading an existing database that already has a `products`
-- table without the subcategory column, run this once (safe to re-run):
-- ALTER TABLE products ADD COLUMN subcategory VARCHAR(100) NULL AFTER category;
-- ALTER TABLE products DROP INDEX ft_search;
-- ALTER TABLE products ADD FULLTEXT KEY ft_search (name, category, subcategory, description);

-- ---------------------------------------------------------
-- Orders (Order Service) - Checkout
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS orders (
  id               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id          INT UNSIGNED NULL,
  customer_name    VARCHAR(150) NOT NULL,
  customer_email   VARCHAR(150) NOT NULL,
  customer_phone   VARCHAR(30)  NOT NULL,
  customer_address TEXT NOT NULL,
  payment_method   ENUM('COD','GCASH','CARD') NOT NULL DEFAULT 'COD',
  total_amount     DECIMAL(10,2) NOT NULL,
  status           ENUM('pending','processing','shipped','completed','cancelled')
                    NOT NULL DEFAULT 'pending',
  created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_orders_user FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS order_items (
  id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id     INT UNSIGNED NOT NULL,
  product_id   INT UNSIGNED NULL,
  product_name VARCHAR(150) NOT NULL,
  unit_price   DECIMAL(10,2) NOT NULL,
  quantity     INT UNSIGNED NOT NULL,
  subtotal     DECIMAL(10,2) NOT NULL,
  CONSTRAINT fk_items_order FOREIGN KEY (order_id) REFERENCES orders(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products(id)
    ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Seed products
-- 3 main categories -> 3 subcategories each -> 5 sample products each
-- (45 products total). Prices are placeholders in PHP pesos.
-- No images are seeded here on purpose — add product photos later
-- through the admin panel. The homepage hero is independent of
-- these products; drop your own promo images into
-- assets/media/hero/ (see index.php) to control it separately.
-- ---------------------------------------------------------
INSERT INTO products (name, category, subcategory, description, price, sale_price, stock, badge) VALUES
-- ===== 1. Athletic & Performance Footwear =====
-- 1A. Road Running Shoes
('Nike Pegasus 41',              'Athletic & Performance Footwear', 'Road Running Shoes',   'Cushioned road runner built for daily mileage and long-distance comfort.', 8200.00, NULL,    15, NULL),
('Brooks Ghost 16',               'Athletic & Performance Footwear', 'Road Running Shoes',   'Cushioned road runner built for daily mileage and long-distance comfort.', 6950.00, NULL,    22, NULL),
('Hoka Clifton 9',                 'Athletic & Performance Footwear', 'Road Running Shoes',   'Cushioned road runner built for daily mileage and long-distance comfort.', 8350.00, NULL,    42, NULL),
('Asics Gel-Kayano 31',           'Athletic & Performance Footwear', 'Road Running Shoes',   'Cushioned road runner built for daily mileage and long-distance comfort.', 6300.00, NULL,     9, NULL),
('Saucony Ride 17',                'Athletic & Performance Footwear', 'Road Running Shoes',   'Cushioned road runner built for daily mileage and long-distance comfort.', 7800.00, NULL,     9, 'New'),
-- 1B. Trail Running Shoes
('Salomon Speedcross 6',          'Athletic & Performance Footwear', 'Trail Running Shoes',  'Rugged trail companion with aggressive grip for off-road terrain.',       8850.00, NULL,    42, NULL),
('Altra Lone Peak 8',              'Athletic & Performance Footwear', 'Trail Running Shoes',  'Rugged trail companion with aggressive grip for off-road terrain.',       8650.00, NULL,    25, NULL),
('Hoka Speedgoat 6',               'Athletic & Performance Footwear', 'Trail Running Shoes',  'Rugged trail companion with aggressive grip for off-road terrain.',       7300.00, NULL,    35, NULL),
('La Sportiva Bushido III',        'Athletic & Performance Footwear', 'Trail Running Shoes',  'Rugged trail companion with aggressive grip for off-road terrain.',       7450.00, 7100.00, 29, 'Sale'),
('Nike Pegasus Trail 5',           'Athletic & Performance Footwear', 'Trail Running Shoes',  'Rugged trail companion with aggressive grip for off-road terrain.',       7900.00, NULL,    30, 'New'),
-- 1C. Training & Gym Shoes
('Nike Metcon 9',                  'Athletic & Performance Footwear', 'Training & Gym Shoes', 'Stable, supportive cross-trainer for lifting, HIIT, and gym sessions.',   5300.00, 4700.00, 37, 'Sale'),
('Reebok Nano X4',                 'Athletic & Performance Footwear', 'Training & Gym Shoes', 'Stable, supportive cross-trainer for lifting, HIIT, and gym sessions.',   5450.00, NULL,    26, 'Best Seller'),
('Under Armour TriBase Reign 6',   'Athletic & Performance Footwear', 'Training & Gym Shoes', 'Stable, supportive cross-trainer for lifting, HIIT, and gym sessions.',   6350.00, 5550.00, 20, 'Sale'),
('Inov-8 F-Lite G 300',            'Athletic & Performance Footwear', 'Training & Gym Shoes', 'Stable, supportive cross-trainer for lifting, HIIT, and gym sessions.',   5900.00, NULL,    26, NULL),
('Puma Fuse 3.0',                  'Athletic & Performance Footwear', 'Training & Gym Shoes', 'Stable, supportive cross-trainer for lifting, HIIT, and gym sessions.',   5500.00, NULL,    32, NULL),

-- ===== 2. Casual & Lifestyle Footwear =====
-- 2A. Everyday Lifestyle Sneakers
('Adidas Stan Smith',              'Casual & Lifestyle Footwear', 'Everyday Lifestyle Sneakers', 'Timeless everyday sneaker that pairs with almost any outfit.', 4750.00, NULL, 18, NULL),
('Nike Air Force 1',                'Casual & Lifestyle Footwear', 'Everyday Lifestyle Sneakers', 'Timeless everyday sneaker that pairs with almost any outfit.', 4450.00, NULL, 12, 'New'),
('Converse Chuck Taylor All Star',  'Casual & Lifestyle Footwear', 'Everyday Lifestyle Sneakers', 'Timeless everyday sneaker that pairs with almost any outfit.', 5300.00, NULL, 23, NULL),
('Vans Old Skool',                  'Casual & Lifestyle Footwear', 'Everyday Lifestyle Sneakers', 'Timeless everyday sneaker that pairs with almost any outfit.', 4450.00, NULL, 22, 'Best Seller'),
('New Balance 574',                 'Casual & Lifestyle Footwear', 'Everyday Lifestyle Sneakers', 'Timeless everyday sneaker that pairs with almost any outfit.', 5000.00, NULL, 20, NULL),
-- 2B. Slip-On & Canvas Shoes
('Vans Classic Slip-On',            'Casual & Lifestyle Footwear', 'Slip-On & Canvas Shoes', 'Easy slip-on comfort for quick errands and relaxed weekends.', 3150.00, NULL, 27, NULL),
('TOMS Alpargata',                  'Casual & Lifestyle Footwear', 'Slip-On & Canvas Shoes', 'Easy slip-on comfort for quick errands and relaxed weekends.', 2450.00, NULL, 31, NULL),
('Skechers GO WALK',                'Casual & Lifestyle Footwear', 'Slip-On & Canvas Shoes', 'Easy slip-on comfort for quick errands and relaxed weekends.', 3400.00, 3000.00, 24, 'Sale'),
('Sperry Striper Slip-On',          'Casual & Lifestyle Footwear', 'Slip-On & Canvas Shoes', 'Easy slip-on comfort for quick errands and relaxed weekends.', 3550.00, NULL, 14, NULL),
('Hey Dude Wally Canvas',           'Casual & Lifestyle Footwear', 'Slip-On & Canvas Shoes', 'Easy slip-on comfort for quick errands and relaxed weekends.', 2900.00, NULL, 33, 'New'),
-- 2C. Retro & Heritage Sneakers
('Puma Suede Classic',              'Casual & Lifestyle Footwear', 'Retro & Heritage Sneakers', 'Retro-inspired silhouette with heritage detailing and a modern feel.', 5100.00, NULL, 19, NULL),
('Adidas Gazelle',                  'Casual & Lifestyle Footwear', 'Retro & Heritage Sneakers', 'Retro-inspired silhouette with heritage detailing and a modern feel.', 5600.00, NULL, 16, 'Best Seller'),
('New Balance 990v5',               'Casual & Lifestyle Footwear', 'Retro & Heritage Sneakers', 'Retro-inspired silhouette with heritage detailing and a modern feel.', 6900.00, NULL, 11, NULL),
('Nike Blazer Mid',                 'Casual & Lifestyle Footwear', 'Retro & Heritage Sneakers', 'Retro-inspired silhouette with heritage detailing and a modern feel.', 5300.00, 4850.00, 21, 'Sale'),
('Onitsuka Tiger Mexico 66',        'Casual & Lifestyle Footwear', 'Retro & Heritage Sneakers', 'Retro-inspired silhouette with heritage detailing and a modern feel.', 4900.00, NULL, 25, NULL),

-- ===== 3. Formal & Dress Footwear =====
-- 3A. Oxfords & Derby Shoes
('Allen Edmonds Park Avenue Oxford','Formal & Dress Footwear', 'Oxfords & Derby Shoes', 'Sharp formal lace-up crafted for boardrooms and black-tie events.', 8900.00, NULL, 8,  'Best Seller'),
('Cole Haan OriginalGrand Derby',   'Formal & Dress Footwear', 'Oxfords & Derby Shoes', 'Sharp formal lace-up crafted for boardrooms and black-tie events.', 6700.00, NULL, 14, NULL),
('Johnston & Murphy Melton Oxford', 'Formal & Dress Footwear', 'Oxfords & Derby Shoes', 'Sharp formal lace-up crafted for boardrooms and black-tie events.', 7400.00, 6900.00, 10, 'Sale'),
('Clarks Tilden Cap Oxford',        'Formal & Dress Footwear', 'Oxfords & Derby Shoes', 'Sharp formal lace-up crafted for boardrooms and black-tie events.', 5900.00, NULL, 17, NULL),
('Steve Madden Jaggar Derby',       'Formal & Dress Footwear', 'Oxfords & Derby Shoes', 'Sharp formal lace-up crafted for boardrooms and black-tie events.', 5750.00, NULL, 19, 'New'),
-- 3B. Loafers & Dress Slip-On Shoes
('G.H. Bass Weejuns Penny Loafer',  'Formal & Dress Footwear', 'Loafers & Dress Slip-On Shoes', 'Polished slip-on loafer that dresses up smart-casual looks.', 6100.00, NULL, 18, 'Best Seller'),
('Sperry Authentic Original Boat Shoe','Formal & Dress Footwear', 'Loafers & Dress Slip-On Shoes', 'Polished slip-on loafer that dresses up smart-casual looks.', 4900.00, NULL, 23, NULL),
('Cole Haan Pinch Penny Loafer',    'Formal & Dress Footwear', 'Loafers & Dress Slip-On Shoes', 'Polished slip-on loafer that dresses up smart-casual looks.', 6600.00, NULL, 12, NULL),
('Florsheim Comet Bit Loafer',      'Formal & Dress Footwear', 'Loafers & Dress Slip-On Shoes', 'Polished slip-on loafer that dresses up smart-casual looks.', 5400.00, 4950.00, 15, 'Sale'),
('Aldo Grandcode Tassel Loafer',    'Formal & Dress Footwear', 'Loafers & Dress Slip-On Shoes', 'Polished slip-on loafer that dresses up smart-casual looks.', 4750.00, NULL, 20, NULL),
-- 3C. Dress Boots
('Red Wing Heritage Iron Ranger',   'Formal & Dress Footwear', 'Dress Boots', 'Rugged yet refined boot that carries from the office to the outdoors.', 11200.00, NULL,    6,  'Best Seller'),
('Thursday Boot Co. Captain Chelsea','Formal & Dress Footwear', 'Dress Boots', 'Rugged yet refined boot that carries from the office to the outdoors.', 8900.00,  NULL,    10, NULL),
('Clarks Bushacre Chukka Boot',     'Formal & Dress Footwear', 'Dress Boots', 'Rugged yet refined boot that carries from the office to the outdoors.', 7300.00,  NULL,    16, NULL),
('Timberland Earthkeepers Boot',    'Formal & Dress Footwear', 'Dress Boots', 'Rugged yet refined boot that carries from the office to the outdoors.', 8600.00,  7900.00, 13, 'Sale'),
('Steve Madden Rochester Boot',     'Formal & Dress Footwear', 'Dress Boots', 'Rugged yet refined boot that carries from the office to the outdoors.', 7200.00,  NULL,    14, 'New');

-- ---------------------------------------------------------
-- v2 modules (wishlist, reviews, notifications, returns,
-- contact messages, CMS pages, banners, settings, audit log,
-- order tracking history, extra profile fields). Kept in a
-- separate file so existing installs can upgrade in place —
-- see sql/upgrade_v2.sql. Fresh installs should run both files:
--   mysql -u root -p < sql/schema.sql
--   mysql -u root -p < sql/upgrade_v2.sql
-- ---------------------------------------------------------
