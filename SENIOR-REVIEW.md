# SoleCraftPH — Senior Review

**Website: 78/100, launchable with caveats. Android app: 62/100, risky.**

Both surfaces work. The app's weak points are a slow, unexplained first paint on the product page, delivery addresses being saved as undeliverable Plus Codes, and 36 MB of dead weight in every download.

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

## The product detail page: slow, and throwing on the way

**I called this a blocker in the first draft of this document. That was wrong**, and the correction matters more than the finding.

I tapped a product, waited about five seconds, screenshotted a blank grey screen, saw an exception in the log, and concluded the page was dead. It is not. Waiting fourteen seconds instead shows the page fully working: image, price, stock count, size selector, quantity stepper, Add to Bag, Buy Now, rating. **The app can take an order.** I had photographed the loading state and read it as the result — the reviewer's version of the bug I was describing.

What is real, and still worth fixing:

**An unhandled exception fires on the way in.** Three times across separate cold starts:

```
I/flutter: Null check operator used on a null value
I/flutter: #0  _ShoeDetailsWidgetState.build
           (package:solecraft_final/pages/shoe_details/shoe_details_widget.dart:280)
```

It is transient — a `!` on something not yet populated during the first build, which resolves when the data arrives and the widget rebuilds. It does not stop the page. It does mean every product open throws, and an exception that is normally harmless is exactly the one that hides a real failure later, because nobody looks twice at a log line they see every time.

**The blank window is long and says nothing.** Roughly five to fourteen seconds of empty screen — no spinner, no skeleton, no product name, nothing carried through from the tile that was just tapped. The user has no way to tell loading from broken, which is precisely the mistake I made with the log in front of me.

**Fixes:** guard line 280 behind the loading state rather than dereferencing with `!`, and paint the page immediately with what the catalog tile already knows — name, price, image — so the wait fills in rather than starting blank.

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

### The app's design

Nine screens captured on the device: catalog, product detail, bag, orders, account, delivery addresses, the address form, the map sheet, and the empty state.

**The app does not look like the shop.** This is the one structural problem and everything else is detail. The website has a real identity — Bebas Neue display type, the SOLE**CRAFT**PH wordmark with CRAFT in blaze red, ink-on-paper, hard edges, a 3px red rule. The app has none of it. The header is "SoleCraftPH" set in a plain bold sans, there is no wordmark, no Bebas, and the red appears only as an error colour. Put the two side by side and they are two different companies. Whatever else gets fixed, a customer who buys on the site and then installs the app should recognise it.

**Screen by screen:**

*Catalog.* A large empty band sits between the category chips and the first product row — roughly 150px of nothing where the eye expects product. The chip row is sliced by the right screen edge with no fade or arrow, so "Formal" reads as broken rather than scrollable. Product titles wrap to two lines while the subtitle truncates mid-word ("Road Running Sh…"), so cards in a row end up different heights. Product photos sit on inconsistent backgrounds — some white, some pale grey — because they are uploaded as-is with no normalisation. The cart badge reads "0" instead of hiding when empty, and overlaps the bag button rather than sitting clear of it.

*Product detail.* In my capture the area between the app bar and the title is blank white where the product image belongs. I could not re-check before the device dropped, so treat this as needing one look rather than as established. The heart in the app bar is filled solid red — if that is the default rather than a wishlist state, it is telling every customer their item is already saved. The rating row reads "★ 5.0 1", where the trailing 1 means "1 review" but says nothing. Price is `₱8200`.

*Bag.* "Proceed to Checkout" is fully enabled on an empty bag at ₱0. The shipping line reads `₱2,000` — a thousands separator on the same screen where the catalog showed none.

*My Orders.* "Order #" sits hard left and "54" hard right, so the label and its value read as two unrelated things. Timestamps are raw SQL: `2026-09-10 02:18:33`. No tap affordance on the cards, so it is unclear whether an order can be opened.

*Notifications.* **68 unread**, every one carrying a red dot, going back days. Nothing marks a notification read on open — only the explicit "Mark all read" button does, so the count only ever grows. A badge that is permanently lit stops being a signal.

Order #000054's history also reads: **Pending → Processing → Completed → Cancelled.** `order_update_status()` validates that the new status is in `ORDER_STATUSES` and nothing else, so any status can follow any other. A completed order can be cancelled, a cancelled one completed, and a delivered one sent back to pending — each firing a customer notification. There is no state machine, and for an order that has been paid for, "Cancelled" arriving after "Completed" is the kind of message that generates a support ticket.

*Account.* The avatar reads **SC** while the signed-in user is `chaxsthexryz` — the initials are the brand's, not the person's, which is the one place on the screen that should feel like theirs. Chevrons appear on "My orders" and "My bag" but not on the five rows above them, so identical-looking rows have different affordances. "Visit the website" prints the raw `snow-jellyfish-553645.hostingersite.com` across two wrapped lines.

*Delivery addresses.* The best-composed screen in the app. Clear cards, a green "Pinned on the map" state, a sensible form. Two flaws: the three actions are undifferentiated text links with Delete in red beside them, so the destructive one sits a thumb's width from "Edit"; and the post-pin confirmation uses that same red for success.

*Map sheet.* Good — clean header, honest attribution, a clear "Drag the map to move the pin" instruction. Undone by the primary button being clipped by the navigation bar, and by printing raw coordinates (`14.671416,121.107482`) to a customer who has no use for them.

**The cross-cutting one: three price formats in one app.** `₱8200` on the catalog, `₱2,000` in the bag, `₱73800` in order history — and `₱8,200.00` on the website. Pick one and put it behind a single formatter.

**Bottom navigation is four unlabelled icons.** A storefront, a bag, a receipt and a person. Bag and receipt are the same silhouette at a glance, and there is no text to disambiguate. Labels are the standard fix and cost one line.

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

**Push notification delivery — proven working, 11 Sep 2026.**

An order was moved to Cancelled in the admin panel with the phone attached. Both halves fired:

- **Server side.** The in-app Notifications list shows `Order #000054 — Cancelled / Your order status changed to "Cancelled". / 2026-09-11 14:34:07`, so `order_update_status()` → `notification_notify_customer()` wrote its row.
- **Push side.** `dumpsys notification` holds `StatusBarNotification(pkg=ph.solecraft.app … tag=FCM-Notification:587927496, channel=fcm_fallback_notification_channel, flags=AUTO_CANCEL)`, sitting at the very top of the device-wide archive — the most recent notification on the phone. It was delivered by FCM and displayed in the status bar, then auto-cancelled.

So the chain works: admin change → `push_send_to_user()` → FCM → device → shade. The service account in `config/fcm.php` is populated, the token registration path in the DSL is wired correctly (auth token in the `Authorization` header, FCM token in the body's `token` field), and the device is registered.

Two things about *how* it arrives are worth fixing:

**It uses `fcm_fallback_notification_channel`.** That is Firebase's own fallback, used because the app never declares a notification channel of its own. In Android's settings the customer sees a generic "Miscellaneous" category rather than something like "Order updates", and you cannot give order notifications their own importance, sound or icon — nor can a customer keep order updates while muting anything else you add later.

**`importance=DEFAULT` and `color=0x00000000`.** No heads-up banner, so an order update lands silently in the shade rather than announcing itself, and the status-bar icon is untinted rather than carrying the blaze accent.

---

**Earlier draft said this was unproven. Superseded — kept below only because it records what could not be reached and why.**

Everything checkable is checked and healthy: `google_app_id`, sender ID and project id are real values baked into the APK; `FirebaseApp initialization successful` on every launch; `FLTFireContextHolder` receives the application context; `POST_NOTIFICATIONS` and `com.google.android.c2dm.permission.RECEIVE` are both granted with `USER_SET`; Google Play Services is installed and its GCM scheduler is running.

What is not proven is that a message actually arrives, and there is no read-only way to prove it:

- The FCM token is fetched in Dart by `messaging.getToken()`, which logs nothing. Nothing in logcat reveals whether the app got a token or registered it with `api/devices.php`.
- `includes/push_service.php` writes every attempt to `../push.log` with `OK`, `SKIP no config/fcm.php yet`, `SKIP user N has no registered device`, `DROP dead token` or `ERROR HTTP nnn`. **That file would answer the question completely** — it is one directory above `public_html`, so it is not reachable over the web, and the hosting file-read API rejects paths containing `..`.
- Sending a push requires a server-side trigger — an admin order-status change, or placing an order — and I have no admin credentials.

**The single fastest way to close this:** open `push.log` in Hostinger's File Manager (one level above `public_html`, beside `paymongo_webhook.log`) and read the last few lines. `SKIP ... has no registered device` means the app never registered its token. `SKIP no config/fcm.php yet` means the service account was never installed. `OK` means push works and always has.

Failing that, change any order's status in the admin panel while the phone is attached, and the log plus logcat together will show whether it lands.

**Token storage — now confirmed, and worse than first written.** `run-as` refuses on a release build, so the file itself cannot be read without root. The APK settles it anyway.

The Dart snapshot carries these persisted app-state keys:

```
ff_authToken   ff_userEmail   ff_userPhone   ff_userAddress
ff_userFullName   ff_userId   ff_username   ff_userRole   ff_isAdmin
ff_signedIn   ff_bag   ff_lastOrderId
```

`classes.dex` contains `FlutterSharedPreferences` — the plugin's plaintext XML file, at `/data/user/0/ph.solecraft.app/shared_prefs/`. Searching the whole APK for any encrypted alternative returns nothing at all:

| Library | Hits in APK |
| --- | --- |
| `shared_preferences` | 3 dex, 15 snapshot |
| `flutter_secure_storage` | **0** |
| `EncryptedSharedPreferences` | **0** |
| `androidx.security` | **0** |

So the session token has no encrypted store available to it even in principle.

**And it leaves the device.** `dumpsys package` reports `flags=[ HAS_CODE ALLOW_CLEAR_USER_DATA ALLOW_BACKUP KILL_AFTER_RESTORE ]`, and there is no `res/xml/` backup-rules file excluding the prefs. `ALLOW_BACKUP` means that XML — the auth token, the customer's email, phone number and home address together — is eligible for Android's automatic cloud backup to the user's Google Drive. That is a copy of a live session credential and a set of personal data sitting outside your control, in an account you do not administer.

**Fix:** move `ff_authToken` to `flutter_secure_storage` (Android Keystore), and either set `android:allowBackup="false"` or add a `dataExtractionRules` file that excludes `shared_prefs`.

**A second thing worth noticing in that key list:** `ff_isAdmin` and `ff_userRole` are persisted client-side. The server must never trust either — it has its own `role` column and does check it, so this is not a live hole. It is worth a deliberate note, because an app that stores its own admin flag in an editable plaintext file is one careless `if (FFAppState().isAdmin)` away from being one.

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

1. **Commit the 46 production files.** Nothing else on this list is safe to attempt while "restore from git" would delete the checkout page.
2. **Strip Plus Codes from saved addresses.** You are storing undeliverable addresses right now — this one is already costing you.
3. **Give the product page a loading state**, and paint name, price and image straight from the tile so the wait fills in instead of starting blank.
4. **Guard `shoe_details_widget.dart:280`** so every product open stops throwing.
5. **Bottom inset on the pin sheet**, so the primary action is not under the nav bar.
6. **Ship an App Bundle** and drop 36 MB from the download.
7. **Hash the API tokens** and revoke them on password change.
8. **Remove `loremflickr.com`** before a customer sees a stranger's shoe as your product.

Two through five are a day between them. Number one is the one that makes the rest safe.
