# SoleCraftPH — Senior Review

**Website: 78/100, launchable with caveats. Android app: 42/100, blocked.**

The site is in decent shape and got better today. The app cannot sell anything: the product detail page throws on every product I could open, and renders a blank grey screen with no error, no message and no way back.

Second pass, 11 Sep 2026. The first pass was code-reading only. This one adds a real device — a Samsung Galaxy A15 5G on Android 16, attached over wireless ADB — and that device overturned two of my earlier conclusions and found a blocker no amount of code reading would have.

---

## What changed since the first pass

Two of the three original blockers are **fixed, deployed and verified** (commit `8fd6d45`):

- **Suspension is enforced per request**, web and mobile. `auth_session_suspended()` runs once per request behind a static cache; the bearer-token resolver joins `users` and excludes suspended accounts.
- **The PayMongo webhook is idempotent.** `order_set_payment_status()` guards on the current value inside the WHERE clause and returns whether it changed anything; the status update and the customer notification hang off that return.

The third — the 26 MB hero video of Nike and Adidas footage — **stays by your decision**, as a test. Not re-argued. It is still not licensed for commercial use and still costs a first-time visitor 13 MB before anything plays.

**I was wrong about two things, and the device proved it:**

1. I wrote that the app had never run on a phone. It had. `ph.solecraft.app` was updated at 21:56 that day, and all three sensitive permissions carry `USER_SET`, meaning a human tapped Allow on a real prompt. The location permission work fires correctly.
2. I listed the FCM configuration as the likely reason push "doesn't work". It is correctly baked into the APK — real `google_app_id`, real sender ID, real API key. That hypothesis is dead.

---

## Blocker: the product detail page is broken

Tap any product in the app and you get a **blank grey screen**. No title, no error, no back button — only the system back gesture, which on the first press leaves the app entirely.

```
I/flutter: Null check operator used on a null value
I/flutter: #0  _ShoeDetailsWidgetState.build
           (package:solecraft_final/pages/shoe_details/shoe_details_widget.dart:280)
```

**Scope, stated precisely:** I opened two products — Nike Pegasus 41 and Brooks Ghost 16 — each from a cold app start, and both threw the identical exception at the identical line. I did not test all 45. But the API payloads for those two are structurally identical to each other and to the rest (same fields, same nulls in `sale_price` and `badge`, same `available_sizes`), so there is no evident reason the other 43 would differ.

**Why nobody noticed:** in a release build Flutter renders a blank container instead of the red error box. There is no crash, no ANR, no dialog. The app looks like it is loading something that never arrives. In a debug build this would have been unmissable.

**What it costs:** the product page is where size is chosen and Add to Cart lives. With it down, the app cannot take an order at all. Everything else — catalog, search, bag, orders, addresses, the map pin — works, which makes the failure easy to miss and total in effect.

**Where to look:** line 280 of `shoe_details_widget.dart`, for a `!` on something that is null at first build. The usual cause in FlutterFlow is a page parameter or an API result dereferenced before it has arrived, rather than guarded behind the loading state.

---

## The app, verified on hardware

Device: Samsung SM-A156E, Android 16 / SDK 36, arm64, 1080×2340 @ 450dpi.

### Confirmed working

- **Catalog** loads live data from the API — real products, real prices, real images.
- **Authentication** works. Signed in as a real account; the bearer token is accepted across endpoints.
- **The map pin works end to end.** GPS fix, OpenStreetMap tiles with attribution, reverse geocode, autofill back into the address field. This was my biggest unknown and it is real.
- **My Orders** loads genuine order history.
- **Firebase initialises**, the FlutterFire messaging plugin loads, `c2dm.permission.RECEIVE` is granted.
- Bag, Account and the empty-bag state all render without exceptions.

### Defects found on the device

**The "Use this location" button is clipped by the navigation bar.** The primary action of the pin flow sits partly beneath the ||| ○ ‹ bar. It is still tappable at its top edge — I confirmed that — but a taller nav bar or a larger system font would swallow it. This is `targetSdk=36` behaviour: Android 16 hands you the whole screen and expects you to respect the bottom inset. The sheet does not. `SafeArea(bottom: true)` on the action row fixes it.

**Plus Codes are being saved as delivery addresses.** Two real saved addresses on this phone:

```
M4F6+977, San Mateo, Calabarzon
M4C4+GXR Permaline Homes, Marikina, Metro Manila
```

`M4F6+977` is a Google Plus Code — what the geocoder returns when the coordinate has no street number. The first has no street component at all. **A courier cannot deliver to that.** Strip a leading Plus Code token when the remainder is non-empty; when it is all you have, say so and ask for landmarks rather than presenting a code as an address.

**The pin confirmation is error-red.** After a successful pin the address appears in `--blaze` red — the same colour as the Delete action. Red reads as failure everywhere. The screen already uses green for "Pinned on the map"; use that.

**"Proceed to Checkout" is fully enabled on an empty bag.** Subtotal ₱0, total ₱0, button live.

**Price formatting is inconsistent, inside the app and against the website:**

| Where | Renders |
| --- | --- |
| App catalog tile | `₱8200` |
| App bag, shipping line | `₱2,000` |
| App order history | `₱73800` |
| Website | `₱8,200.00` |

Three formats in one product. This is the drift I predicted from two implementations of the same logic, and it is already shipped.

**Raw database timestamps are shown to customers.** Order history reads `2026-09-10 02:18:33`. That is a SQL datetime, not a date a person should be handed.

**"Order #" and its number are split** to opposite ends of the row, so it reads as `Order #` … `54`. The website pads to `Order #000054`.

**My Orders takes between 5 and 20 seconds to load**, showing only a bare spinner. It does resolve — I let it run and it did — but there is no skeleton, no message and no timeout.

**The "Pin on map" button becomes an unlabelled spinner** while GPS acquires, roughly 10 seconds indoors, with no cancel and no timeout.

**The category chip row is sliced by the right screen edge** with no scroll affordance, so "Formal" reads as broken rather than scrollable.

**The bottom navigation is four unlabelled icons.** Bag and receipt are hard to tell apart.

### The APK itself

**55.2 MB, of which 53 MB is native libraries for three ABIs:**

| ABI | Size | Used by |
| --- | --- | --- |
| `arm64-v8a` | 18 MB | every modern phone |
| `armeabi-v7a` | 16 MB | phones from ~2015 |
| `x86_64` | 20 MB | emulators only |

**About 36 MB of every download is dead weight.** Ship an Android App Bundle, or split per ABI, and the download drops to roughly 20 MB. The x86_64 slice in particular can never execute on a customer's phone.

**A placeholder image service is compiled into the production binary:** `https://loremflickr.com/600/600/sneaker`. If any product lacks an image, the app fetches a *random stranger's sneaker photo* from a lorem-ipsum service and shows it as your product.

**`https://api.whatsapp.com/send`** is also compiled in — worth confirming that is a deliberate support link.

**The base URL is hardcoded** to `snow-jellyfish-553645.hostingersite.com`. Every installed APK keeps calling that host until reinstalled, so the day you move to a real domain, already-installed apps break.

**The map uses OpenStreetMap's public tile server.** Their usage policy excludes apps like this and they enforce it by blocking. Fine for a demo; it will start returning 429s under real traffic.

**A stale duplicate app is installed:** `com.mycompany.solecraftfinal`, the untouched FlutterFlow template package, from 8 Sep. It holds `INTERNET` and nothing else — no notifications, no location, no FCM. Anyone in the group testing *that* icon would see push and GPS silently do nothing and conclude the features are broken.

### Not measurable, and not measured

**Scroll performance.** `dumpsys gfxinfo` reports `Total frames rendered: 0` because Flutter's Impeller/Vulkan backend bypasses HWUI entirely. That is a limitation of the tool, not a result. Jank cannot be measured objectively on this build; it needs a profile build and Flutter DevTools.

**Push notification delivery.** The plumbing is verified — config baked in, Firebase initialised, permission granted, Play Services present — but no message has been proven to arrive. Testing it means changing a real order's status to fire a notification, which writes to live order data. Not done without your say-so.

**Token storage.** `run-as` refuses: `package not debuggable`. The plaintext-`shared_preferences` finding stays a code-reading inference, not a device-verified fact.

---

## The website

Two blockers fixed today. What remains, in order:

**API tokens are stored in plaintext** in `api_tokens.token` and compared with `WHERE token = ?`. Anything that reads one row of that table owns every mobile session it holds, with no cracking. You hash the password correctly with bcrypt and then store the credential that bypasses it in the clear. Store `hash('sha256', $token)` and look up by the hash.

**`Access-Control-Allow-Origin: *`** on every API endpoint, including addresses, orders and profile. Not exploitable today — auth is a Bearer header, not a cookie, so a browser attaches nothing automatically and the wildcard cannot be combined with credentials. The finding is that it is a loaded gun with the safety on: the day anyone adds a cookie or a web client, it becomes a data leak, in a different file, written by someone who never read this one.

**The catalog silently truncates at 100 products.** `product_list()` has `int $limit = 100`, no offset, no page parameter and nothing in the UI admitting a limit exists. Product 101 is invisible and nothing reports it. You have 45.

**`user_delete()` hard-deletes a customer** and I still cannot confirm the foreign-key behaviour on `orders.user_id`. Either it fails with a constraint error the admin does not handle, or it cascades and destroys financial records. Check before anyone clicks it.

**The webhook log is unbounded and attacker-writable.** Every rejected signature appends the full request body to `../paymongo_webhook.log`. It is outside `public_html`, which is the important part, but anyone who knows the URL can grow it without limit and it holds customer names and addresses.

**`support@solecraftph.local` does not resolve.** It is on the contact page and in the privacy policy.

**No meta description, no Open Graph, no sitemap.** A shop with no share preview and no SEO surface.

**~20 dead `_*.php` stubs and three 0-byte `.bak` files** in `public_html`. All 403 today, one bad `.htaccess` edit from not being.

**CSP is `upgrade-insecure-requests` and nothing else.** A real one would be painful because inline `<style>` and `<script>` are everywhere. The difficulty is the finding.

---

## The gap between the repository and production

This is new, and it is the finding with the longest shadow.

**The git repository does not contain most of the deployed website.**

| Directory | On the server | In the repo | Missing |
| --- | --- | --- | --- |
| document root | 24 PHP files | 9 | **15** |
| `admin/` | 24 | 3 | **21** |
| `includes/` | 24 | 15 | **9** |
| `api/` | 13 | 12 | **1** |

**Roughly 46 production files are not under version control.** Among them: `checkout.php`, `register.php`, `profile.php`, `contact.php`, `page.php`, `serve_image.php`, `manifest.php`, `sw.php`, the entire admin panel bar three screens, `includes/header.php`, `includes/paymongo_service.php` — which holds the webhook signature verification the fix I deployed today depends on — and `api/my_orders.php`, which the app calls on every visit to Order History.

Three consequences:

1. **There is no rollback.** "Restore from git" would delete the checkout page, the registration page and twenty admin screens. The repo is not a backup; it is a partial working copy.
2. **`git log` is not a history of this system.** Most of what runs has no recorded authorship, no diff, no reason-for-change.
3. **Review is impossible for those files.** Nobody can review a change to `checkout.php` because `checkout.php` has never been committed.

There is also visible duplication in `admin/`: `orders.php` beside `admin_orders.php`, `order_detail.php` beside `admin_order_detail.php`. Two pairs of near-identical files, both live, and a future change has to find both.

**This is the first thing I would fix on the web side**, ahead of the token hashing. It costs one `git add` of the files pulled down from the server and it is the precondition for everything else being safe to change.

---

## What is genuinely good

Short on purpose; the useful half of this document is above.

- **CSRF by construction.** `csrf_autoinject()` puts a token into every POST form on the way out and skips GET forms and non-HTML responses. It cannot be forgotten on a new form, which is where every per-form implementation eventually fails.
- **The stock transaction is correct.** `SELECT ... FOR UPDATE` on both the product and the size row, inside a transaction, before any write. Most people get concurrent checkout wrong.
- **The payment trust boundary is right.** Orders are marked paid by the signed webhook only, never the browser's return trip.
- **Secrets hygiene.** `.gitignore` covers the real credential files; `git ls-files` shows only the `.sample.php` versions.
- **Headers**, verified over HTTP rather than assumed: HSTS with `includeSubDomains`, `nosniff`, `X-Frame-Options`, `Referrer-Policy: strict-origin-when-cross-origin`, and a session cookie with `Secure`, `HttpOnly`, `SameSite=Lax`.
- **`.htaccess` genuinely enforces.** `config/`, `includes/`, `sql/`, `.bak` and `.git` all return 403 — twelve paths tested live.
- **The app's location handling is correct** on a real Android 16 device, with real user-granted permissions.
- 45 product images all carry `loading="lazy"`; TTFB 0.49 s; 65 KB of HTML.

---

## Evidence checked

- Live device: Samsung SM-A156E over wireless ADB — cold-start logcat, per-PID logs, permission dumps, nine screenshots, `dumpsys package`, `dumpsys activity`, `gfxinfo`
- APK pulled from the device and unpacked: manifest, ABI payloads, `resources.arsc`, Dart AOT snapshot string table
- Server file listings for `/`, `admin/`, `includes/`, `api/`, compared against the repo
- Thirteen API endpoints probed live for status codes
- `includes/auth.php`, `csrf.php`, `order_service.php`, `product_service.php`, `webhook/paymongo.php`
- Live HTTP: response headers, `.htaccess` enforcement on twelve paths, page weights and timings

## Evidence missing

- **The `orders.user_id` foreign key.** Decides the `user_delete()` finding.
- **`serve_image.php` and `config/app.php`** — not in the repo, not fetched. `serve_image.php` takes a parameter and serves a file, the classic shape of a path-traversal bug. **Worth a look.**
- **Push delivery**, which needs a real order-status change.
- **The other 43 product pages**, though two of two failed identically.

---

## What I would do, in order

1. **Fix `shoe_details_widget.dart:280`.** The app cannot sell anything until this is done.
2. **Commit the 46 production files.** Until then there is no rollback for anything else on this list.
3. **Strip Plus Codes from saved addresses.** You are storing undeliverable addresses right now.
4. **Bottom inset on the pin sheet**, so the primary action is not under the nav bar.
5. **Ship an App Bundle** and drop 36 MB from the download.
6. **Hash the API tokens** and revoke them on password change.
7. **Remove `loremflickr.com`** before a customer sees a stranger's shoe as your product.

One through four are a day. Number two is the one that makes the rest safe to attempt.
