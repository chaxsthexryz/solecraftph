# SoleCraftPH mobile app — review

**Reviewed:** 9 September 2026
**Scope:** FlutterFlow project `solecraftfinal-egt61q` — 17 pages, 2 components, and the generated Flutter code
**Method:** read the generated Dart and the project tree directly. Every claim names the file it came from.

---

## Verdict

The app is feature-complete against the website now — seven screens went in today and the parity list is closed. Architecture is sound: it treats the server as the source of truth, renders verdicts the server computes rather than deciding for itself, and shares one cart and one price calculation with the storefront.

The weaknesses are concentrated in one place, and it happens to be the one thing a shoe store cannot get wrong: **size selection**. There is a silent wrong default, no stock validation, and a picker that offers sizes you may not have. Everything else in this document is ordinary polish by comparison.

---

## What is good

- **Server-side authority.** `can_review`, cart contents, order ownership, prices — all computed server-side and rendered by the app. A tampered client cannot review a shoe it never bought or set its own price.
- **The cart is genuinely shared.** Add on the phone, see it on the website. The push/pull design (whole-bag replace on change, pull on Bag open) avoids the drift that per-item sync produces.
- **Payment is handled correctly.** In-app WebView to PayMongo, order settled by webhook rather than by the redirect. That is the right design.
- **One theme, matching the storefront.** Buttons on a single spec, brand tokens read from the site's own CSS.

---

## Critical — these affect orders

### 1. The size defaults to US 9 and nothing warns the customer

`generated_code/lib/pages/shoe_details/shoe_details_model.dart:27`

```dart
String? selectedSize = '9';
```

A customer who opens a shoe and taps **Add to Bag** without touching the size row gets a **US 9**, silently. No prompt, no validation, no visual cue that a choice was made on their behalf. They will find out when the parcel arrives.

The website already refuses this — `cart.php` answers *"Please choose a size first"* and the product page's dropdown starts empty and is `required`. The app is the inconsistent one.

**Fix:** default `selectedSize` to empty, and refuse the tap with a message until one is chosen. Small change, and it is the highest-value thing in this document.

### 2. Add to Bag never checks stock

There is no stock check anywhere in the Add to Bag chain — a search of the generated widget for `stock` in that path returns nothing. A customer can put 50 of a shoe you have one of into their bag, and only discover it at checkout, after entering their address and choosing a payment method.

The server now refuses the order correctly (`order_create` locks the row and verifies), so you will not oversell. But the failure arrives at the worst possible moment.

**Fix:** compare `qty` against the shoe's stock before adding, and cap the quantity stepper.

### 3. The size picker ignores what is actually in stock

The six size buttons are hardcoded — `selectedSize = '7'` through `'12'`, six literal assignments in the widget. They do not consult availability, so the app will happily offer a US 12 you have none of.

The API now returns `available_sizes` on every product (added today, driven by the new `product_sizes` table). Nothing consumes it yet.

**Fix:** bind each size button's enabled state to `available_sizes`. This is what makes per-size stock visible to customers rather than just enforced at checkout.

### 4. An expired session shows blank screens, not a prompt

No 401 handling exists anywhere — no widget checks `statusCode == 401`.

API tokens last 30 days. On day 31, `authToken` is still sitting in app state and still being sent, so every authenticated call fails. Bag, Orders, Profile, Notifications and Wishlist all render empty with no explanation, and the app never suggests signing in again. The same thing happens the moment a password is changed, because that deliberately revokes every token.

**Fix:** on a 401, clear `authToken` and `signedIn`, then send the customer to Sign In with "Your session expired, please sign in again."

---

## Important

### 5. Admin settings do not reach the app

Two things the website reads from the database, the app hardcodes:

| | Website | App |
|---|---|---|
| Payment methods | `settings_enabled_payment_methods()` | three literal buttons: `COD`, `GCASH`, `CARD` |
| Categories | every distinct category in `products` | three literal strings in the Shop chips |

Turning GCash off in admin turns it off on the website and leaves it on in the app — customers will pick a method you have disabled. Adding a fourth product category makes it appear on the site and stay invisible in the app.

### 6. No offline or connection handling

Nothing in the project references connectivity or `SocketException`. On a dropped connection an API call fails and the screen shows an empty list — indistinguishable from "you have no orders". Given this is a phone app in the Philippines, patchy connections are the normal case, not the edge case.

### 7. No pull-to-refresh anywhere

Zero `RefreshIndicator` in the project. The Bag pulls on open and Notifications loads once, but a customer who wants to check whether their order shipped has to leave the screen and come back. Pull-to-refresh is the gesture everyone reaches for first.

### 8. Missing loading states

Shop, MyOrders and Checkout have progress indicators. **ShoeDetails and Bag have none** — they show empty space while loading, which reads as "nothing here" rather than "one moment".

### 9. Notifications are in-app only

The bell shows what is in the `notifications` table, which is genuinely useful. But nothing reaches a closed app — no Firebase, no device tokens, no push. "Your order shipped" is only seen by someone who happens to open the app.

This is a real feature (Firebase project, `device_tokens` table, a send hook on status change), not a toggle. Worth planning rather than squeezing in.

---

## Before the Play Store

### 10. The package name is still the FlutterFlow placeholder

`generated_code/android/app/src/main/AndroidManifest.xml:2`

```
package="com.mycompany.solecraftfinal"
```

**This is permanent once published.** A Play Store listing's package name can never be changed — a different one is a different app, with no shared reviews, installs or update path. Change it to something you own the shape of, like `ph.solecraft.app`, before your first upload. It costs nothing today and cannot be fixed later.

### 11. The app label is shouting

`android:label="SOLECRAFT FINAL"` — that is the name under the icon on every customer's home screen. "SoleCraftPH" is the brand; "FINAL" is a filename habit from the project, not something a customer should ever see.

### 12. A privacy policy must be reachable

Play Store requires one for an app handling accounts and addresses. You have the content — `page.php?slug=privacy` and the Help screen reads it — so this is a matter of putting the URL in the listing, not writing anything new. Worth confirming the Help screen actually renders it before you rely on it.

---

## What I would fix, in order

1. **Size default and the add-to-bag guard** (Critical 1) — one silent bug producing wrong-size deliveries
2. **Bind the size picker to `available_sizes`** (Critical 3) — the API already returns it
3. **Stock check before adding** (Critical 2) — moves the failure to where the customer can act on it
4. **401 handling** (Critical 4) — every account in the app will hit this within 30 days
5. **Package name and app label** (10, 11) — five minutes now, impossible later
6. **Read payment methods and categories from the server** (5)
7. **Pull-to-refresh and the two missing loading states** (7, 8)
8. **Offline messaging** (6)
9. **Push notifications** (9) — the largest, and fine to defer

Items 1–4 are roughly a session's work together and remove every way the app can currently mislead a customer about what they are buying.

---

## A closing observation

Nothing here is architectural. The hard parts — shared cart, server-side authority, correct payment settlement — were done right, and they are the parts that are expensive to fix later.

What is missing is the layer that assumes things go wrong: no size chosen, no stock left, no signal, an expired session. The app currently reads as though the happy path is the only path. On a phone, in a shop, it is not.
