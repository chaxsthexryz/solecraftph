# SoleCraftPH — security and hygiene inspection

**Date:** 9 September 2026
**Scope:** the live website, the API, and the FlutterFlow app
**Method:** probed the running site and read the source. Every finding below was reproduced, not inferred.

---

## First: something I broke, and have fixed

The in-place patches I ran earlier wrote `.bak` files next to the originals, **inside the document root**. `.bak` is not executed by PHP, so Apache served them as plain text:

```
checkout.php.bak            200   <?php require_once __DIR__ . '/config/app.php'; ...
profile.php.bak             200   <?php ...
admin/order_detail.php.bak  200   <?php require_once __DIR__ . '/../includes/auth.php'; ...
```

Anyone who guessed those URLs could read your source, including the shape of the auth checks. **All three are now zero bytes**, verified, and the site still answers 200 everywhere.

This was not a subtlety. Backups belong outside `public_html`, and I put them inside it. Worth stating plainly because it is the most serious thing this inspection found, and it was self-inflicted.

---

## What is genuinely good

Not filler — these are the things I went looking to criticise and could not.

- **Output escaping is disciplined.** Every echo of customer-supplied text goes through `htmlspecialchars`. The handful of unescaped ones are integers and computed counts (`$p['id']`, `$reviewSummary['count']`), which cannot carry a payload. No stored XSS found.
- **Server-side authority throughout.** Prices are re-read from `products` at order time, stock is checked under `SELECT … FOR UPDATE`, review eligibility is computed server-side. A tampered client cannot set its own price or review a shoe it never bought.
- **Ownership is enforced, not assumed.** `address_find()` scopes by `user_id`; passing someone else's address id returns 404 rather than their data. Verified live.
- **Payment never touches your server.** PayMongo handles cards and GCash on its own pages; the webhook settles the order.
- **HTTP redirects to HTTPS** (301) and the session cookie carries `secure`.
- **The SQL migrations are not on the server** — all `upgrade_v*.sql` return 404. They exist only in the repo, which is right.

---

## Findings

### 1. The session cookie has no `HttpOnly`

```
Set-Cookie: PHPSESSID=…; path=/; secure
```

`secure` is there. `HttpOnly` is not, and neither is `SameSite`.

Without `HttpOnly`, any script running on the page can read the session cookie via `document.cookie`. Today I found no XSS to exploit that with — but `HttpOnly` is the control that makes an XSS survivable rather than a full account takeover, including an admin's.

**Fix** — one call, before every `session_start()`:

```php
session_set_cookie_params([
    'httponly' => true,
    'secure'   => true,
    'samesite' => 'Lax',
]);
```

`includes/auth.php:8` and `includes/cart.php:19` both call `session_start()`, so it belongs above both — most cleanly in `config/app.php`.

### 2. No CSRF tokens on any form

There are **14 POST forms** across the site and not one carries a token. That includes changing a password, placing an order, deleting a saved address, and — the one that matters most — the admin forms for order status, product edits and store settings.

Modern browsers default `SameSite=Lax`, which blocks cross-site POSTs and takes most of the sting out of this. But that is a browser default doing your security for you, not a control you own, and setting `SameSite` explicitly (finding 1) is the cheap half of the fix.

**Fix:** a token in `$_SESSION`, a hidden field in each form, and a check on POST. Start with `admin/*` — a CSRF that flips an order to "delivered" or edits a price is worth more to an attacker than one that deletes a customer's address.

### 3. `README.md` is publicly readable

9,980 bytes at `/README.md`, describing every admin file path, the module layout, and how the pieces fit together. Nothing secret is in it — no credentials — but it is a map of the application handed to anyone who asks, including `admin/settings.php`, `admin/returns.php` and the rest.

**Fix:** deny it, or move it out of `public_html`. It belongs in the repo, not on the server.

### 4. No security headers

Only `content-security-policy: upgrade-insecure-requests`, which Hostinger adds. Missing:

| Header | What its absence allows |
|---|---|
| `X-Content-Type-Options: nosniff` | MIME sniffing on uploaded files |
| `X-Frame-Options: SAMEORIGIN` | Clickjacking — your admin in an invisible iframe |
| `Strict-Transport-Security` | A first visit over HTTP before the 301 |
| `Referrer-Policy` | Order ids leaking in `Referer` to third parties |

Four lines in `.htaccess`.

### 5. Output is being sent before the headers

Every include emits four spaces before anything else:

```
GET /includes/auth.php            → 4 bytes:  "    "
GET /includes/product_service.php → 4 bytes:  "    "
GET /api/settings.php             → "    {"cod":true,…"
```

Something in the `config/` include chain has whitespace outside its PHP tags. Every API response carries it, which will break any strict JSON parser you point at this API later.

The worse part is latent: output starting before `header()` should produce "headers already sent" and drop your `Content-Type`. It does not, because output buffering happens to be on in this PHP configuration. **Your API works by virtue of a php.ini setting.** Move hosts, or have that flipped, and every JSON endpoint starts failing at once.

**Fix:** find the file with a blank line or BOM before `<?php` or after `?>`, and drop the closing `?>` from every pure-PHP file — PSR-12 says omit it precisely to prevent this.

### 6. Only login is rate limited

`login_throttle` guards sign-in properly — verified earlier at `401×5 → 429`. Nothing else is:

- **Registration** — accounts can be created in bulk
- **Password reset** — `?action=forgot` can be fired repeatedly at one address, using your Gmail SMTP to flood someone's inbox

The throttle helper already exists; it needs applying to both.

### 7. `includes/` is reachable over HTTP

`/includes/auth.php` returns 200. PHP executes it, so no source leaks — but it is doing nothing useful and should be denied, exactly like `config/` already is.

---

## App

Covered in `APP-REVIEW.md` and `CHECKOUT-AND-BROWSE.md`; both lists are now closed. Two things remain worth saying:

**Nothing has been tested on a physical device.** Every fix is verified in the generated Dart. Push notifications and the GPS pin button cannot be verified any other way, and the search bug proves why that matters — the submit handler was correct and provably unreachable, and only a real keyboard would have shown it.

**Three near-duplicate endpoints have accumulated:** `GetProducts`/`GetProductsFiltered`, `CreateOrder`/`CreateOrderPinned`, and `AuthSession` sitting beside `?action=me`. Each exists because FlutterFlow's `ensure*` helpers are create-if-missing and refuse to change an endpoint's shape. That is the platform's rule, not a choice — but the older half of each pair is now dead and could be deleted through the FlutterFlow UI.

---

## Order I would fix these

| | Finding | Effort |
|---|---|---|
| 1 | `HttpOnly` + `SameSite` on the session cookie | 5 min |
| 2 | Deny `README.md` and `includes/`; add the four headers | 15 min |
| 3 | Find and remove the stray whitespace | 20 min |
| 4 | Throttle registration and password reset | 30 min |
| 5 | CSRF tokens, admin forms first | 2–3 hrs |

Items 1–3 are configuration and cost almost nothing. Item 5 is the real work, and it is the one that stops mattering only when someone tries it.

None of this is unusual for a store at this stage, and none of it is architectural. The foundations — server-side pricing, stock locking, escaped output, ownership checks — are the parts that would have been expensive to get wrong, and they are right.
