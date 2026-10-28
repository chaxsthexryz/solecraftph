# SoleCraftPH

An online footwear store for the Philippines, with a website and a mobile app that share one account, cart and order system.

- **Website:** https://snow-jellyfish-553645.hostingersite.com
- **Admin panel:** https://snow-jellyfish-553645.hostingersite.com/admin/

## What it does

**Customers (website and app)**
- Browse, search, sort and filter shoes by category, size, price, sale and stock
- Product pages with a photo gallery, sizes, star ratings and reviews
- Cart with selectable items, vouchers (e.g. `WELCOME10`), and a full cost breakdown
- Checkout with a map pin for the delivery address
- Pay by Cash on Delivery, GCash or card (PayMongo)
- Order history with photos, a tracking timeline, cancellations and return requests
- Wishlist, saved addresses, notifications, Google sign-in, password reset by email
- Help assistant on every shop page: finds shoes by budget, size and style, and answers questions about shipping, payment, returns, vouchers, sizing and the customer's own orders

**Admin (separate site at `/admin/`)**
- Two-step sign-in: password, then a 6-digit code sent by email
- Dashboard with Today / 30-day / 90-day filters: revenue, orders, average order, pairs sold, new customers, and charts for revenue, order status, payment methods and top products
- Sales report download (CSV) and print view
- Inventory with per-size stock and low-stock alerts, product add/edit, banners, vouchers
- Orders, returns, reviews, customers, admin accounts
- Support messages with replies sent by email
- Site content, store settings, notifications and an audit trail

## Project layout

| Folder | What's in it |
|---|---|
| `server-patch/` | The PHP website, admin panel and the JSON API the app uses (deployed to Hostinger) |
| `server-patch/api/` | API endpoints: auth, products, cart, orders, payments, addresses, assistant, and more |
| `server-patch/admin/` | Admin panel pages |
| `server-patch/includes/` | Shared services: auth, cart, orders, products, mail, vouchers, PayMongo |
| `server-patch/sql/` | Database schema and upgrade scripts |
| `solecraftph/`, `solecraftfinal/` | FlutterFlow workspaces for the mobile app |
| `flutter_solecraft/` | Flutter project files |

## Tech stack

- **Website and API:** PHP 8, MySQL, vanilla JavaScript, Chart.js, Leaflet with OpenStreetMap
- **Mobile app:** Flutter, built with FlutterFlow
- **Payments:** PayMongo (GCash and cards)
- **Email:** PHPMailer over Gmail SMTP
- **Hosting:** Hostinger

## Running the website locally

1. Create a MySQL database and import `server-patch/sql/schema.sql`, then the `upgrade_*.sql` files in order.
2. Copy the sample configs in `server-patch/config/` (`mail.sample.php`, `fcm.sample.php`) and fill in your own database, mail and payment details. Never commit real keys.
3. Serve `server-patch/` with PHP 8 (for example `php -S localhost:8000 -t server-patch`) and open http://localhost:8000.

## Security notes

- Passwords are hashed with bcrypt, and every form carries a CSRF token
- Sign-in, registration, password reset and the contact form are rate-limited
- Admin accounts need an emailed code to sign in and can't use the shop login or the app
- Customers can only see their own orders, on the website and through the API

## Team

Made by John Lawrence Balitos and team.
