# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users
Filipino shoppers buying sneakers on their phone (tested on a Samsung Galaxy A15, Android 16). Evaluated as a Group 9 school project: the audience that matters most is the instructor/panel watching a live demo of browse → detail → bag → checkout.

## Product Purpose
SoleCraft PH is the mobile storefront for a PHP e-commerce site (snow-jellyfish-553645.hostingersite.com). Customers browse shoes, pick a size, add to bag, check out with Cash on Delivery or PayMongo (TEST mode only), track orders, and get push notifications on status changes. Success = the full shopping flow works smoothly and looks professional in a demo.

## Operating Context
- Built in FlutterFlow (project `solecraftfinal-egt61q`); all changes go through `dsl/edit.dart` via `flutterflow ai run`. `generated_code/` is a read-only download.
- Data comes from the site's REST API (`api/*.php`) with bearer tokens.
- Delivery addresses are pinned on a map (flutter_map) with Plus Code stripping.

## Capabilities and Constraints
- 18 pages: shop, shoe_details, bag, checkout, payment, confirmed, my_orders, order_detail, account, profile, addresses, wishlist, reviews, notifications, help, info_page, sign_in, register. Components: shoe_card, cat_chip, pin_sheet.
- Android behavior stays native: system back gesture, Android system bars, bottom nav bar.
- PayMongo stays in TEST mode; no real payments.
- No paid services. Low-end phones: avoid heavy blur/glass effects.
- Product detail pages can take ~5s to load for the first items (network), so loading states matter.

## Brand Commitments
- Name: SoleCraft PH.
- Colors the user asked to keep: ink `#111111`, accent red-orange `#E2412A`, warm off-white ground `#FAF9F6`, white surfaces `#FFFFFF`, warm grey `#8A8578`.
- Binding visual brief (user, 2026-09-29): "Apple Store app" inspired UI and buttons, keeping the SoleCraft theme colors. Apple look, Android behavior.

## Evidence on Hand
- Product photos come from the site's uploads via the API; placeholder fallback is the app icon.
- No testimonials, ratings data beyond the in-app reviews feature, or press. Do not fabricate any.

## Product Principles
1. The demo path (Shop → Detail → Bag → Checkout) must be flawless before anything else.
2. Product photography leads; chrome recedes.
3. Never imply real money moves: payment is test-only.
4. Native Android expectations win over visual imitation.
