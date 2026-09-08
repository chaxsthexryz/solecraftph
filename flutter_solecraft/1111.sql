-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1:3306
-- Generation Time: Aug 31, 2026 at 12:41 PM
-- Server version: 11.8.8-MariaDB-log
-- PHP Version: 7.2.34

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `u775139998_solecraftph`
--

-- --------------------------------------------------------

--
-- Table structure for table `audit_log`
--

CREATE TABLE `audit_log` (
  `id` int(10) UNSIGNED NOT NULL,
  `admin_id` int(10) UNSIGNED DEFAULT NULL,
  `admin_username` varchar(60) DEFAULT NULL,
  `action` varchar(100) NOT NULL,
  `details` varchar(500) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `audit_log`
--

INSERT INTO `audit_log` (`id`, `admin_id`, `admin_username`, `action`, `details`, `created_at`) VALUES
(1, 1, 'admin', 'Product updated', 'Nike Pegasus 41', '2026-08-25 14:42:59'),
(2, 1, 'admin', 'Product updated', 'Brooks Ghost 16', '2026-08-31 06:48:47');

-- --------------------------------------------------------

--
-- Table structure for table `banners`
--

CREATE TABLE `banners` (
  `id` int(10) UNSIGNED NOT NULL,
  `title` varchar(150) NOT NULL,
  `subtitle` varchar(255) DEFAULT NULL,
  `link_url` varchar(255) DEFAULT NULL,
  `sort_order` int(11) NOT NULL DEFAULT 0,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `cms_pages`
--

CREATE TABLE `cms_pages` (
  `id` int(10) UNSIGNED NOT NULL,
  `slug` varchar(80) NOT NULL,
  `title` varchar(150) NOT NULL,
  `content` longtext NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `cms_pages`
--

INSERT INTO `cms_pages` (`id`, `slug`, `title`, `content`, `updated_at`) VALUES
(1, 'about', 'About Us', 'SoleCraftPH is a footwear storefront dedicated to authentic, fairly-priced shoes for every Filipino.\n\nEdit this page any time from the admin panel (Content > Pages).', '2026-08-25 14:39:28'),
(2, 'faq', 'FAQs', 'Q: How long does delivery take?\nA: 3-5 business days nationwide.\n\nQ: Do you accept COD?\nA: Yes, Cash on Delivery is available nationwide.\n\nEdit this page any time from the admin panel (Content > Pages).', '2026-08-25 14:39:28'),
(3, 'privacy', 'Privacy Policy', 'We respect your privacy. Your personal information is only used to process your orders and is never sold to third parties.\n\nEdit this page any time from the admin panel (Content > Pages).', '2026-08-25 14:39:28');

-- --------------------------------------------------------

--
-- Table structure for table `contact_messages`
--

CREATE TABLE `contact_messages` (
  `id` int(10) UNSIGNED NOT NULL,
  `name` varchar(150) NOT NULL,
  `email` varchar(150) NOT NULL,
  `subject` varchar(200) NOT NULL,
  `message` text NOT NULL,
  `status` enum('new','read','resolved') NOT NULL DEFAULT 'new',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `notifications`
--

CREATE TABLE `notifications` (
  `id` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED DEFAULT NULL,
  `audience` enum('customer','admin') NOT NULL DEFAULT 'customer',
  `title` varchar(150) NOT NULL,
  `message` varchar(500) NOT NULL,
  `is_read` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `orders`
--

CREATE TABLE `orders` (
  `id` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED DEFAULT NULL,
  `customer_name` varchar(150) NOT NULL,
  `customer_email` varchar(150) NOT NULL,
  `customer_phone` varchar(30) NOT NULL,
  `customer_address` text NOT NULL,
  `payment_method` enum('COD','GCASH','CARD') NOT NULL DEFAULT 'COD',
  `total_amount` decimal(10,2) NOT NULL,
  `status` enum('pending','processing','shipped','completed','cancelled') NOT NULL DEFAULT 'pending',
  `tracking_number` varchar(100) DEFAULT NULL,
  `admin_notes` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `orders`
--

INSERT INTO `orders` (`id`, `user_id`, `customer_name`, `customer_email`, `customer_phone`, `customer_address`, `payment_method`, `total_amount`, `status`, `tracking_number`, `admin_notes`, `created_at`, `updated_at`) VALUES
(5, NULL, 'App Test', 'apptest@example.com', '09171234567', '123 Test St, QC', 'COD', 8200.00, 'pending', NULL, NULL, '2026-08-31 06:38:11', '2026-08-31 06:38:11');

-- --------------------------------------------------------

--
-- Table structure for table `order_items`
--

CREATE TABLE `order_items` (
  `id` int(10) UNSIGNED NOT NULL,
  `order_id` int(10) UNSIGNED NOT NULL,
  `product_id` int(10) UNSIGNED DEFAULT NULL,
  `product_name` varchar(150) NOT NULL,
  `unit_price` decimal(10,2) NOT NULL,
  `quantity` int(10) UNSIGNED NOT NULL,
  `subtotal` decimal(10,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `order_items`
--

INSERT INTO `order_items` (`id`, `order_id`, `product_id`, `product_name`, `unit_price`, `quantity`, `subtotal`) VALUES
(2, 5, 1, 'Nike Pegasus 41', 8200.00, 1, 8200.00);

-- --------------------------------------------------------

--
-- Table structure for table `order_status_log`
--

CREATE TABLE `order_status_log` (
  `id` int(10) UNSIGNED NOT NULL,
  `order_id` int(10) UNSIGNED NOT NULL,
  `status` varchar(30) NOT NULL,
  `note` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `products`
--

CREATE TABLE `products` (
  `id` int(10) UNSIGNED NOT NULL,
  `name` varchar(150) NOT NULL,
  `category` varchar(100) NOT NULL,
  `subcategory` varchar(100) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `price` decimal(10,2) NOT NULL,
  `sale_price` decimal(10,2) DEFAULT NULL,
  `stock` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `low_stock_threshold` int(10) UNSIGNED NOT NULL DEFAULT 5,
  `badge` varchar(40) DEFAULT NULL,
  `image` varchar(255) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `products`
--

INSERT INTO `products` (`id`, `name`, `category`, `subcategory`, `description`, `price`, `sale_price`, `stock`, `low_stock_threshold`, `badge`, `image`, `is_active`, `created_at`, `updated_at`) VALUES
(1, 'Nike Pegasus 41', 'Athletic & Performance Footwear', 'Road Running Shoes', 'Cushioned road runner built for daily mileage and long-distance comfort.', 8200.00, NULL, 14, 5, NULL, 'prod_6a8da9f3a2120.jpg', 1, '2026-08-25 14:29:59', '2026-08-31 06:38:11'),
(2, 'Brooks Ghost 16', 'Athletic & Performance Footwear', 'Road Running Shoes', 'Cushioned road runner built for daily mileage and long-distance comfort.', 6950.00, NULL, 22, 5, NULL, 'prod_6a9523cf8484b.jpg', 1, '2026-08-25 14:29:59', '2026-08-31 06:48:47'),
(3, 'Hoka Clifton 9', 'Athletic & Performance Footwear', 'Road Running Shoes', 'Cushioned road runner built for daily mileage and long-distance comfort.', 8350.00, NULL, 42, 5, NULL, 'https://loremflickr.com/600/600/running,shoe,sneaker?lock=3', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(4, 'Asics Gel-Kayano 31', 'Athletic & Performance Footwear', 'Road Running Shoes', 'Cushioned road runner built for daily mileage and long-distance comfort.', 6300.00, NULL, 9, 5, NULL, 'https://loremflickr.com/600/600/running,shoe,sneaker?lock=4', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(5, 'Saucony Ride 17', 'Athletic & Performance Footwear', 'Road Running Shoes', 'Cushioned road runner built for daily mileage and long-distance comfort.', 7800.00, NULL, 9, 5, 'New', 'https://loremflickr.com/600/600/running,shoe,sneaker?lock=5', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(6, 'Salomon Speedcross 6', 'Athletic & Performance Footwear', 'Trail Running Shoes', 'Rugged trail companion with aggressive grip for off-road terrain.', 8850.00, NULL, 42, 5, NULL, 'https://loremflickr.com/600/600/running,shoe,sneaker?lock=6', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(7, 'Altra Lone Peak 8', 'Athletic & Performance Footwear', 'Trail Running Shoes', 'Rugged trail companion with aggressive grip for off-road terrain.', 8650.00, NULL, 25, 5, NULL, 'https://loremflickr.com/600/600/running,shoe,sneaker?lock=7', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(8, 'Hoka Speedgoat 6', 'Athletic & Performance Footwear', 'Trail Running Shoes', 'Rugged trail companion with aggressive grip for off-road terrain.', 7300.00, NULL, 35, 5, NULL, 'https://loremflickr.com/600/600/running,shoe,sneaker?lock=8', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(9, 'La Sportiva Bushido III', 'Athletic & Performance Footwear', 'Trail Running Shoes', 'Rugged trail companion with aggressive grip for off-road terrain.', 7450.00, 7100.00, 29, 5, 'Sale', 'https://loremflickr.com/600/600/running,shoe,sneaker?lock=9', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(10, 'Nike Pegasus Trail 5', 'Athletic & Performance Footwear', 'Trail Running Shoes', 'Rugged trail companion with aggressive grip for off-road terrain.', 7900.00, NULL, 30, 5, 'New', 'https://loremflickr.com/600/600/running,shoe,sneaker?lock=10', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(11, 'Nike Metcon 9', 'Athletic & Performance Footwear', 'Training & Gym Shoes', 'Stable, supportive cross-trainer for lifting, HIIT, and gym sessions.', 5300.00, 4700.00, 37, 5, 'Sale', 'https://loremflickr.com/600/600/running,shoe,sneaker?lock=11', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(12, 'Reebok Nano X4', 'Athletic & Performance Footwear', 'Training & Gym Shoes', 'Stable, supportive cross-trainer for lifting, HIIT, and gym sessions.', 5450.00, NULL, 26, 5, 'Best Seller', 'https://loremflickr.com/600/600/running,shoe,sneaker?lock=12', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(13, 'Under Armour TriBase Reign 6', 'Athletic & Performance Footwear', 'Training & Gym Shoes', 'Stable, supportive cross-trainer for lifting, HIIT, and gym sessions.', 6350.00, 5550.00, 20, 5, 'Sale', 'https://loremflickr.com/600/600/running,shoe,sneaker?lock=13', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(14, 'Inov-8 F-Lite G 300', 'Athletic & Performance Footwear', 'Training & Gym Shoes', 'Stable, supportive cross-trainer for lifting, HIIT, and gym sessions.', 5900.00, NULL, 26, 5, NULL, 'https://loremflickr.com/600/600/running,shoe,sneaker?lock=14', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(15, 'Puma Fuse 3.0', 'Athletic & Performance Footwear', 'Training & Gym Shoes', 'Stable, supportive cross-trainer for lifting, HIIT, and gym sessions.', 5500.00, NULL, 32, 5, NULL, 'https://loremflickr.com/600/600/running,shoe,sneaker?lock=15', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(16, 'Adidas Stan Smith', 'Casual & Lifestyle Footwear', 'Everyday Lifestyle Sneakers', 'Timeless everyday sneaker that pairs with almost any outfit.', 4750.00, NULL, 18, 5, NULL, 'https://loremflickr.com/600/600/sneaker,shoe?lock=16', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(17, 'Nike Air Force 1', 'Casual & Lifestyle Footwear', 'Everyday Lifestyle Sneakers', 'Timeless everyday sneaker that pairs with almost any outfit.', 4450.00, NULL, 12, 5, 'New', 'https://loremflickr.com/600/600/sneaker,shoe?lock=17', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(18, 'Converse Chuck Taylor All Star', 'Casual & Lifestyle Footwear', 'Everyday Lifestyle Sneakers', 'Timeless everyday sneaker that pairs with almost any outfit.', 5300.00, NULL, 23, 5, NULL, 'https://loremflickr.com/600/600/sneaker,shoe?lock=18', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(19, 'Vans Old Skool', 'Casual & Lifestyle Footwear', 'Everyday Lifestyle Sneakers', 'Timeless everyday sneaker that pairs with almost any outfit.', 4450.00, NULL, 22, 5, 'Best Seller', 'https://loremflickr.com/600/600/sneaker,shoe?lock=19', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(20, 'New Balance 574', 'Casual & Lifestyle Footwear', 'Everyday Lifestyle Sneakers', 'Timeless everyday sneaker that pairs with almost any outfit.', 5000.00, NULL, 20, 5, NULL, 'https://loremflickr.com/600/600/sneaker,shoe?lock=20', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(21, 'Vans Classic Slip-On', 'Casual & Lifestyle Footwear', 'Slip-On & Canvas Shoes', 'Easy slip-on comfort for quick errands and relaxed weekends.', 3150.00, NULL, 27, 5, NULL, 'https://loremflickr.com/600/600/sneaker,shoe?lock=21', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(22, 'TOMS Alpargata', 'Casual & Lifestyle Footwear', 'Slip-On & Canvas Shoes', 'Easy slip-on comfort for quick errands and relaxed weekends.', 2450.00, NULL, 31, 5, NULL, 'https://loremflickr.com/600/600/sneaker,shoe?lock=22', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(23, 'Skechers GO WALK', 'Casual & Lifestyle Footwear', 'Slip-On & Canvas Shoes', 'Easy slip-on comfort for quick errands and relaxed weekends.', 3400.00, 3000.00, 24, 5, 'Sale', 'https://loremflickr.com/600/600/sneaker,shoe?lock=23', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(24, 'Sperry Striper Slip-On', 'Casual & Lifestyle Footwear', 'Slip-On & Canvas Shoes', 'Easy slip-on comfort for quick errands and relaxed weekends.', 3550.00, NULL, 14, 5, NULL, 'https://loremflickr.com/600/600/sneaker,shoe?lock=24', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(25, 'Hey Dude Wally Canvas', 'Casual & Lifestyle Footwear', 'Slip-On & Canvas Shoes', 'Easy slip-on comfort for quick errands and relaxed weekends.', 2900.00, NULL, 33, 5, 'New', 'https://loremflickr.com/600/600/sneaker,shoe?lock=25', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(26, 'Puma Suede Classic', 'Casual & Lifestyle Footwear', 'Retro & Heritage Sneakers', 'Retro-inspired silhouette with heritage detailing and a modern feel.', 5100.00, NULL, 19, 5, NULL, 'https://loremflickr.com/600/600/sneaker,shoe?lock=26', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(27, 'Adidas Gazelle', 'Casual & Lifestyle Footwear', 'Retro & Heritage Sneakers', 'Retro-inspired silhouette with heritage detailing and a modern feel.', 5600.00, NULL, 16, 5, 'Best Seller', 'https://loremflickr.com/600/600/sneaker,shoe?lock=27', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(28, 'New Balance 990v5', 'Casual & Lifestyle Footwear', 'Retro & Heritage Sneakers', 'Retro-inspired silhouette with heritage detailing and a modern feel.', 6900.00, NULL, 11, 5, NULL, 'https://loremflickr.com/600/600/sneaker,shoe?lock=28', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(29, 'Nike Blazer Mid', 'Casual & Lifestyle Footwear', 'Retro & Heritage Sneakers', 'Retro-inspired silhouette with heritage detailing and a modern feel.', 5300.00, 4850.00, 21, 5, 'Sale', 'https://loremflickr.com/600/600/sneaker,shoe?lock=29', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(30, 'Onitsuka Tiger Mexico 66', 'Casual & Lifestyle Footwear', 'Retro & Heritage Sneakers', 'Retro-inspired silhouette with heritage detailing and a modern feel.', 4900.00, NULL, 25, 5, NULL, 'https://loremflickr.com/600/600/sneaker,shoe?lock=30', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(31, 'Allen Edmonds Park Avenue Oxford', 'Formal & Dress Footwear', 'Oxfords & Derby Shoes', 'Sharp formal lace-up crafted for boardrooms and black-tie events.', 8900.00, NULL, 8, 5, 'Best Seller', 'https://loremflickr.com/600/600/leather,dress,shoe?lock=31', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(32, 'Cole Haan OriginalGrand Derby', 'Formal & Dress Footwear', 'Oxfords & Derby Shoes', 'Sharp formal lace-up crafted for boardrooms and black-tie events.', 6700.00, NULL, 14, 5, NULL, 'https://loremflickr.com/600/600/leather,dress,shoe?lock=32', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(33, 'Johnston & Murphy Melton Oxford', 'Formal & Dress Footwear', 'Oxfords & Derby Shoes', 'Sharp formal lace-up crafted for boardrooms and black-tie events.', 7400.00, 6900.00, 10, 5, 'Sale', 'https://loremflickr.com/600/600/leather,dress,shoe?lock=33', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(34, 'Clarks Tilden Cap Oxford', 'Formal & Dress Footwear', 'Oxfords & Derby Shoes', 'Sharp formal lace-up crafted for boardrooms and black-tie events.', 5900.00, NULL, 17, 5, NULL, 'https://loremflickr.com/600/600/leather,dress,shoe?lock=34', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(35, 'Steve Madden Jaggar Derby', 'Formal & Dress Footwear', 'Oxfords & Derby Shoes', 'Sharp formal lace-up crafted for boardrooms and black-tie events.', 5750.00, NULL, 19, 5, 'New', 'https://loremflickr.com/600/600/leather,dress,shoe?lock=35', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(36, 'G.H. Bass Weejuns Penny Loafer', 'Formal & Dress Footwear', 'Loafers & Dress Slip-On Shoes', 'Polished slip-on loafer that dresses up smart-casual looks.', 6100.00, NULL, 18, 5, 'Best Seller', 'https://loremflickr.com/600/600/leather,dress,shoe?lock=36', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(37, 'Sperry Authentic Original Boat Shoe', 'Formal & Dress Footwear', 'Loafers & Dress Slip-On Shoes', 'Polished slip-on loafer that dresses up smart-casual looks.', 4900.00, NULL, 23, 5, NULL, 'https://loremflickr.com/600/600/leather,dress,shoe?lock=37', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(38, 'Cole Haan Pinch Penny Loafer', 'Formal & Dress Footwear', 'Loafers & Dress Slip-On Shoes', 'Polished slip-on loafer that dresses up smart-casual looks.', 6600.00, NULL, 12, 5, NULL, 'https://loremflickr.com/600/600/leather,dress,shoe?lock=38', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(39, 'Florsheim Comet Bit Loafer', 'Formal & Dress Footwear', 'Loafers & Dress Slip-On Shoes', 'Polished slip-on loafer that dresses up smart-casual looks.', 5400.00, 4950.00, 15, 5, 'Sale', 'https://loremflickr.com/600/600/leather,dress,shoe?lock=39', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(40, 'Aldo Grandcode Tassel Loafer', 'Formal & Dress Footwear', 'Loafers & Dress Slip-On Shoes', 'Polished slip-on loafer that dresses up smart-casual looks.', 4750.00, NULL, 20, 5, NULL, 'https://loremflickr.com/600/600/leather,dress,shoe?lock=40', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(41, 'Red Wing Heritage Iron Ranger', 'Formal & Dress Footwear', 'Dress Boots', 'Rugged yet refined boot that carries from the office to the outdoors.', 11200.00, NULL, 6, 5, 'Best Seller', 'https://loremflickr.com/600/600/leather,dress,shoe?lock=41', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(42, 'Thursday Boot Co. Captain Chelsea', 'Formal & Dress Footwear', 'Dress Boots', 'Rugged yet refined boot that carries from the office to the outdoors.', 8900.00, NULL, 10, 5, NULL, 'https://loremflickr.com/600/600/leather,dress,shoe?lock=42', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(43, 'Clarks Bushacre Chukka Boot', 'Formal & Dress Footwear', 'Dress Boots', 'Rugged yet refined boot that carries from the office to the outdoors.', 7300.00, NULL, 16, 5, NULL, 'https://loremflickr.com/600/600/leather,dress,shoe?lock=43', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(44, 'Timberland Earthkeepers Boot', 'Formal & Dress Footwear', 'Dress Boots', 'Rugged yet refined boot that carries from the office to the outdoors.', 8600.00, 7900.00, 13, 5, 'Sale', 'https://loremflickr.com/600/600/leather,dress,shoe?lock=44', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17'),
(45, 'Steve Madden Rochester Boot', 'Formal & Dress Footwear', 'Dress Boots', 'Rugged yet refined boot that carries from the office to the outdoors.', 7200.00, NULL, 14, 5, 'New', 'https://loremflickr.com/600/600/leather,dress,shoe?lock=45', 1, '2026-08-25 14:29:59', '2026-08-31 06:45:17');

-- --------------------------------------------------------

--
-- Table structure for table `product_reviews`
--

CREATE TABLE `product_reviews` (
  `id` int(10) UNSIGNED NOT NULL,
  `product_id` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `rating` tinyint(3) UNSIGNED NOT NULL,
  `comment` text DEFAULT NULL,
  `status` enum('pending','approved','rejected') NOT NULL DEFAULT 'approved',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ;

-- --------------------------------------------------------

--
-- Table structure for table `returns`
--

CREATE TABLE `returns` (
  `id` int(10) UNSIGNED NOT NULL,
  `order_id` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED DEFAULT NULL,
  `reason` varchar(150) NOT NULL,
  `details` text DEFAULT NULL,
  `status` enum('requested','approved','rejected','refunded') NOT NULL DEFAULT 'requested',
  `admin_notes` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `settings`
--

CREATE TABLE `settings` (
  `setting_key` varchar(60) NOT NULL,
  `setting_value` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `settings`
--

INSERT INTO `settings` (`setting_key`, `setting_value`) VALUES
('currency_symbol', '₱'),
('free_shipping_threshold', '2000'),
('low_stock_default_threshold', '5'),
('payment_card_enabled', '1'),
('payment_cod_enabled', '1'),
('payment_gcash_enabled', '1'),
('shipping_fee', '150'),
('store_name', 'SoleCraftPH'),
('support_email', 'support@solecraftph.local'),
('support_phone', '0917-000-0000');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` int(10) UNSIGNED NOT NULL,
  `username` varchar(60) NOT NULL,
  `full_name` varchar(150) DEFAULT NULL,
  `email` varchar(150) NOT NULL,
  `phone` varchar(30) DEFAULT NULL,
  `address` text DEFAULT NULL,
  `password_hash` varchar(255) NOT NULL,
  `role` enum('admin','customer') NOT NULL DEFAULT 'customer',
  `status` enum('active','suspended') NOT NULL DEFAULT 'active',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `username`, `full_name`, `email`, `phone`, `address`, `password_hash`, `role`, `status`, `created_at`) VALUES
(1, 'admin', NULL, 'admin@solecraftph.local', NULL, NULL, '$2b$10$JIDh.jMUXXr0KRb6iTriouDEUgM58z7CbdC86AbFWfDBek6PnR7vq', 'admin', 'active', '2026-08-25 14:29:59');

-- --------------------------------------------------------

--
-- Table structure for table `wishlists`
--

CREATE TABLE `wishlists` (
  `id` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `product_id` int(10) UNSIGNED NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `audit_log`
--
ALTER TABLE `audit_log`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_audit_admin` (`admin_id`);

--
-- Indexes for table `banners`
--
ALTER TABLE `banners`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `cms_pages`
--
ALTER TABLE `cms_pages`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `slug` (`slug`);

--
-- Indexes for table `contact_messages`
--
ALTER TABLE `contact_messages`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `notifications`
--
ALTER TABLE `notifications`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_notif_user` (`user_id`);

--
-- Indexes for table `orders`
--
ALTER TABLE `orders`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_orders_user` (`user_id`);

--
-- Indexes for table `order_items`
--
ALTER TABLE `order_items`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_items_order` (`order_id`),
  ADD KEY `fk_items_product` (`product_id`);

--
-- Indexes for table `order_status_log`
--
ALTER TABLE `order_status_log`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_statuslog_order` (`order_id`);

--
-- Indexes for table `products`
--
ALTER TABLE `products`
  ADD PRIMARY KEY (`id`);
ALTER TABLE `products` ADD FULLTEXT KEY `ft_search` (`name`,`category`,`subcategory`,`description`);

--
-- Indexes for table `product_reviews`
--
ALTER TABLE `product_reviews`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_review_product` (`product_id`),
  ADD KEY `fk_review_user` (`user_id`);

--
-- Indexes for table `returns`
--
ALTER TABLE `returns`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_return_order` (`order_id`),
  ADD KEY `fk_return_user` (`user_id`);

--
-- Indexes for table `settings`
--
ALTER TABLE `settings`
  ADD PRIMARY KEY (`setting_key`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `username` (`username`),
  ADD UNIQUE KEY `email` (`email`);

--
-- Indexes for table `wishlists`
--
ALTER TABLE `wishlists`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_wishlist` (`user_id`,`product_id`),
  ADD KEY `fk_wishlist_product` (`product_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `audit_log`
--
ALTER TABLE `audit_log`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `banners`
--
ALTER TABLE `banners`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `cms_pages`
--
ALTER TABLE `cms_pages`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `contact_messages`
--
ALTER TABLE `contact_messages`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `notifications`
--
ALTER TABLE `notifications`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `orders`
--
ALTER TABLE `orders`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `order_items`
--
ALTER TABLE `order_items`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `order_status_log`
--
ALTER TABLE `order_status_log`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `products`
--
ALTER TABLE `products`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=46;

--
-- AUTO_INCREMENT for table `product_reviews`
--
ALTER TABLE `product_reviews`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `returns`
--
ALTER TABLE `returns`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `wishlists`
--
ALTER TABLE `wishlists`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `audit_log`
--
ALTER TABLE `audit_log`
  ADD CONSTRAINT `fk_audit_admin` FOREIGN KEY (`admin_id`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `notifications`
--
ALTER TABLE `notifications`
  ADD CONSTRAINT `fk_notif_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `orders`
--
ALTER TABLE `orders`
  ADD CONSTRAINT `fk_orders_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `order_items`
--
ALTER TABLE `order_items`
  ADD CONSTRAINT `fk_items_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_items_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `order_status_log`
--
ALTER TABLE `order_status_log`
  ADD CONSTRAINT `fk_statuslog_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `product_reviews`
--
ALTER TABLE `product_reviews`
  ADD CONSTRAINT `fk_review_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_review_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `returns`
--
ALTER TABLE `returns`
  ADD CONSTRAINT `fk_return_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_return_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `wishlists`
--
ALTER TABLE `wishlists`
  ADD CONSTRAINT `fk_wishlist_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_wishlist_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
