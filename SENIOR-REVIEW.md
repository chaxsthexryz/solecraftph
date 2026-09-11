# SoleCraftPH — Senior Review

**Production audit: 64/100, risky.** Ship behind an internal beta. The PayMongo webhook is not idempotent and a suspended account keeps full access until it logs out — those two are the reason for the number, not the general quality of the code, which is better than the score suggests.

Scope: the PHP storefront (`server-patch/`) and the FlutterFlow Android app (`solecraftfinal/`), as they stand on 11 Sep 2026 at commit `4802c33`.

---

## The short version

The security fundamentals here are genuinely better than most projects at this stage. CSRF is covered on every form by construction rather than by discipline. Stock is decremented under row locks inside a transaction. The webhook signature is verified and the browser redirect is correctly not trusted. Secrets are gitignored and I confirmed they are not in the history. `.htaccess` really does return 403 for `config/`, `includes/`, `sql/`, `.bak` and `.git` — I checked each one over HTTP rather than taking the file's word for it.

What is weak is everything around that core: nothing is tested, nothing is measured, and several features were built and never once exercised on the device they are meant to run on. The gap between "the code is right" and "we know the code is right" is the whole of this review.

And one thing on the site right now is actively harmful, which I put first because I built it.

---

## Blockers

### 1. The hero video is 26 MB of someone else's trademarks

I shipped this today at your request, and it is the worst thing on the site.

Three clips, 40.5s + 19.5s + 18.5s. The first is 13 MB and it downloads before anything plays. On Philippine mobile data that is real money out of a visitor's pocket to watch an advert, and a multi-second black hero while it buffers. The rule of thumb for a background loop is 6–12 seconds and under 4 MB. You are 3× over on both.

The licensing is worse. All three are Nike and Adidas spec commercials. They are third-party trademarks, used on a live storefront that sells shoes, which is the exact context trademark law exists to police. Clip 1 drifts a large Adidas wordmark directly over "BUILT FOR EVERY STEP YOU TAKE" — so it is also a design failure on its own terms, with their brand beating yours in your own hero.

**Fix:** replace with your own footage, or footage under a licence that permits commercial use, trimmed to ~8s and compressed to ~3 MB. If you cannot get footage, the type-only hero that was there this morning was better than this.

### 2. A suspended account keeps working until it logs out

> **Fixed and live, 11 Sep 2026, commit `8fd6d45`.** `auth_session_suspended()` runs once per request behind a static cache and `auth_is_logged_in()` consults it, so all 23 including files inherit it. The mobile half is closed too — `auth_user_id_from_bearer_token()` now excludes suspended accounts, so a token issued before the suspension stops working immediately instead of lasting its full TTL. Original finding below.

`includes/auth.php` enforces suspension in exactly one place — `auth_attempt_login()`. `auth_current_user()` selects the `status` column and never reads it. The comment above it states the behaviour as if it were a decision:

> "A logged-in user's own record is blocked from checking their own status (suspension is enforced at login)"

So suspending an account does nothing to a session that already exists. The person you are banning — for fraud, for abuse, for chargebacks — keeps browsing, keeps ordering, and keeps their cart until they choose to log out. Sessions have no fixed lifetime, so that may be never.

**Fix:** one `status === 'suspended'` check in `auth_current_user()`, returning null and destroying the session. Every page already calls it.

### 3. The PayMongo webhook is not idempotent

> **Fixed and live, 11 Sep 2026, commit `8fd6d45`.** The guard went inside `order_set_payment_status()`, which had exactly one caller and was itself the thing that was not idempotent. It is a conditional `UPDATE ... WHERE payment_status <> ?` returning `rowCount() > 0`, not a read-then-check, so two deliveries racing each other cannot both win. The webhook hangs the status update and the notification on that return. Original finding below.

`webhook/paymongo.php` verifies the signature correctly and then acts unconditionally on every delivery:

```php
order_set_payment_status($orderId, 'paid');
order_update_status($orderId, 'processing', 'Payment confirmed via PayMongo.');
```

PayMongo retries. That is not an edge case, it is the documented contract of every payment webhook — network blips, timeouts, and their own at-least-once delivery all produce redeliveries of an event you already handled.

The damage is concrete, and it is in `order_update_status()` at `includes/order_service.php:249`: every call writes another `order_status_log` row *and* calls `notification_notify_customer()`. So three redeliveries of one payment mean the customer gets three "Order #000123 — Processing" push notifications for one purchase, and the order history shows the same transition three times. To the customer that looks like the shop is broken, or like they were charged three times.

**Fix:** four lines at the top of the handler — read the order, return 200 immediately if `payment_status` is already `paid`. Better still, store PayMongo's event id and reject a repeat.

---

## High-value fixes

### 4. API tokens are stored in plaintext and outlive a password change

`api/auth.php` mints `bin2hex(random_bytes(32))` — good entropy — and then stores the raw value in `api_tokens.token`, comparing it with `WHERE token = ?`.

Anything that can read one row of that table has every mobile account it contains, with no cracking required. This is the same mistake as storing plaintext passwords, one layer along: you hash the password correctly with bcrypt and then store the credential that bypasses it in the clear.

`auth_change_password()` also does not delete the user's tokens. Someone who changes their password because they think they were compromised stays compromised on mobile for the rest of the token's life.

**Fix:** store `hash('sha256', $token)`, look up by the hash, return the raw token only once at issue. Add one `DELETE FROM api_tokens WHERE user_id = ?` to the password change.

### 5. `Access-Control-Allow-Origin: *` on every API endpoint

Present on `addresses.php`, `orders.php`, `profile.php`, `cart.php` — every endpoint that serves personal data.

It is not exploitable today, and I want to be accurate about that: auth is a Bearer header, not a cookie, so a browser will not attach credentials automatically and the wildcard cannot be combined with them. The finding is that this is a loaded gun with the safety on. The day anyone adds a cookie, a web client, or a session fallback, `*` becomes a data leak — and it will be one line in a different file, written by someone who never reads this one.

**Fix:** echo a specific allowed origin, or drop CORS entirely — a native app does not send preflights and does not need it.

### 6. The catalog silently truncates at 100 products

`product_list()` takes `int $limit = 100` and there is no offset, no page parameter, and nothing in the UI that says a limit exists. Add the 101st product and it does not appear. The admin sees it saved, the shop does not show it, and nothing anywhere reports a problem. You have 45 products, so this is invisible right now and will be invisible on the day it starts costing you sales.

### 7. Nothing is tested, and nothing is green

35 commits, zero tests on the PHP. The single Dart test asserts that the *starter template* DSL compiles — not your app:

```dart
final app = buildApp(starter.buildStarterCreateFlow);
expect(findPage(project, name: 'StarterPage'), isNotNull);
```

No CI. Every check in this project has been a human looking at a page, including every one I did this session. That works until the change is subtle: the day someone edits `order_service.php` and the stock locking silently stops locking, nothing will tell you until you oversell.

You do not need a suite. You need three: place an order end to end, redeliver a webhook twice and assert one notification, and log in with a suspended account.

### 8. `user_delete()` on a customer with orders is unverified

```php
db()->prepare('DELETE FROM users WHERE id = ?')->execute([$id]);
```

I could not confirm the foreign-key behaviour on `orders.user_id` — the Hostinger connector dropped before I could read the schema, so I am flagging this as unverified rather than asserting it. There are two outcomes and both are bad: the delete fails with a constraint error the admin UI does not handle, or it cascades and destroys financial records that should be retained.

**Check before anyone clicks that button.** Soft-delete is almost certainly what you want.

---

## Smaller, still real

- **The webhook log is unbounded and attacker-writable.** Every rejected signature appends the full request body to `../paymongo_webhook.log`. Anyone who knows the URL can grow that file without limit, and it holds real customer names and addresses. It is outside `public_html`, which is the important part, but rotate it.
- **`support@solecraftph.local` does not resolve.** It is on the contact page and in the privacy policy. A customer emailing it gets a bounce, and a privacy policy with an unreachable contact is not a privacy policy.
- **~20 dead `_*.php` stubs and two 0-byte `.bak` files in `public_html`.** All 403 today. They are one bad `.htaccess` edit from not being, and `.bak` files serving PHP as plain text has already happened to you once on this project.
- **CSP is `upgrade-insecure-requests` and nothing else.** No `script-src`, no `style-src`. A real CSP would be painful here because inline `<style>` and `<script>` are everywhere — including in the hero I wrote today. The difficulty is the finding.
- **No meta description, no Open Graph, no sitemap.** A shop with zero share preview and zero SEO surface. `robots.txt` exists and is 58 bytes.
- **"SS26 COLLECTION" above the hero headline.** A kicker above a heading adds a line the reader must process before the line that matters. Delete it.
- **Duplicate API endpoints** — `GetProducts`/`GetProductsFiltered`, `CreateOrder`/`CreateOrderPinned`. Two of each, both live, and a future change has to find both.

---

## The mobile app

### 9. It has never run on a phone

This is the largest unknown in the project and it is not close.

Push notifications, the GPS pin, the location permission prompt, the map rendering, FCM token registration — every one of these can only fail on a real device, and not one has been on one. They are verified to *compile* and to exist in the generated project. That is not the same claim.

An emulator will not surface a missing FCM config, a permission the user denies twice, or a map that renders at 4fps on a mid-range Android. Install the APK on one real phone before anything else on this list.

### 10. The auth token sits in shared_preferences

`ff.AppState.authToken` is FlutterFlow app state, which persists to `shared_preferences` — plaintext XML on device storage. Any rooted device, any ADB backup, any malicious app with storage access reads it. `flutter_secure_storage` exists and puts it in the Android Keystore.

### 11. The base URL is hardcoded to the free Hostinger subdomain

```dart
baseUrl: 'https://snow-jellyfish-553645.hostingersite.com/api',
```

The day you point a real domain at this, every endpoint in the DSL needs editing, and any APK already installed keeps calling the old host until it is reinstalled. Make it one constant now while it is cheap.

### 12. The map uses OpenStreetMap's public tile server

```dart
const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
```

OSM's tile usage policy explicitly excludes apps like this: it requires an identifying User-Agent, forbids bulk use, and they enforce it by blocking. Fine for a demo, and it will start returning 429s the moment there is traffic. Swap for a provider with a free tier and a key.

### 13. The DSL is 5,319 lines in one function

`dsl/edit.dart` is one re-runnable build function. It works, and idempotency is a genuinely good property to have chosen. But nobody can review a 5,000-line function, and this file has already bitten you once: `app.ensurePage` silently skips the body of a page that already exists, which threw away an entire session's edits without an error. That class of bug is invisible precisely because the file is too big to hold in your head.

Split it by surface — auth, catalog, cart, checkout, profile — each callable independently.

---

## The structural thing nobody will notice until it hurts

The website and the app share a database but not a line of code. `api/cart.php` reimplements what `includes/cart.php` already does; `api/orders.php` reimplements `includes/order_service.php`. Two implementations of "add to cart" and "place an order" that must agree forever, maintained by five people, with no test asserting that they do.

They will drift. Probably over something small — a stock check on one side and not the other, a price rounding difference. The fix is not a rewrite: it is that `api/*.php` should call the same service functions `includes/` already exposes and do nothing but translate JSON. Most of them are close to that already. The ones that are not are where your next real bug lives.

---

## What is genuinely good

Kept short on purpose, because the useful half of this document is above.

- **CSRF by construction.** `csrf_autoinject()` puts the token into every POST form on the way out, and skips GET forms and non-HTML responses. It cannot be forgotten on a new form, which is the failure mode every per-form implementation eventually hits. The file documents its own limit (JS-built forms) honestly.
- **The stock transaction is correct.** `SELECT ... FOR UPDATE` on both the product and the size row, inside a transaction, before any write. That is the right answer to concurrent checkout and most people get it wrong.
- **The payment trust boundary is right.** Orders are marked paid by the signed webhook only, never by the browser's return trip. The comment explains why. This is the part people most often get backwards.
- **Secrets hygiene.** `.gitignore` covers the real credential files and I confirmed `git ls-files` shows only the `.sample.php` versions.
- **Headers.** HSTS with `includeSubDomains`, `nosniff`, `X-Frame-Options`, `Referrer-Policy: strict-origin-when-cross-origin`, and a session cookie with `Secure`, `HttpOnly` and `SameSite=Lax`. Verified over HTTP, not assumed.
- **Login throttling** exists on both the web form and the mobile endpoint.
- **All 45 product images carry `loading="lazy"`.** TTFB 0.49s, 65 KB of HTML.

---

## Evidence checked

- `git log` (35 commits), `git ls-files`, `.gitignore`
- `includes/`: `auth.php`, `csrf.php`, `order_service.php`, `product_service.php`
- `api/`: `auth.php` plus CORS headers across all 12 endpoints
- `webhook/paymongo.php`
- `solecraftfinal/dsl/edit.dart`, `test/app_test.dart`, `generated_code/android/app/src/main/AndroidManifest.xml`
- Live HTTP: response headers, `.htaccess` enforcement on 12 paths, homepage weight and timing, image sizes, lazy-loading count
- Live browser at 1440 and 375: hero video playback, clip handover, layout

## Evidence missing

- The `orders.user_id` foreign-key definition — the connector dropped mid-read. This is what finding 8 turns on.
- `config/app.php` and `serve_image.php` are not in the local mirror and I could not fetch them. `serve_image.php` takes a parameter and serves a file, which is the classic shape of a path-traversal bug. **Worth a look.**
- Any evidence at all from a physical Android device.

---

## What I would do, in order

1. Pull the hero video. It is costing you money and it is not yours to use.
2. Four lines for webhook idempotency.
3. One line for the suspension check.
4. Install the APK on a real phone and find out what is actually broken.
5. Hash the API tokens.

The first three are an afternoon. The fourth is the one that will change what you think this project's real problems are.
