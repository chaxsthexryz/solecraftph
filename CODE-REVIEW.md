# SoleCraftPH — engineering review

**Reviewed:** 9 September 2026
**Scope:** `public_html` (PHP storefront + mobile API), FlutterFlow project `solecraftfinal-egt61q`, MySQL `u775139998_solecraftph`
**Method:** live probes against the deployed site, source read from the server, FlutterFlow project inspection. Every claim below is something I checked, not something I assumed.

---

## Verdict

You have built a genuinely complete two-client commerce system — a PHP storefront, an admin back office, a REST API, and a native app that share one database, one cart, and one payment integration. That is more than most solo projects get to, and the architecture is sound: a service layer under `includes/`, thin endpoints on top, and the app treating the server as the source of truth rather than keeping its own parallel state.

The gaps are not architectural. They are the things that get skipped when a project has never had a real customer: account recovery, transactional email, stock correctness, and abuse protection. **Two of them will produce angry customers on day one**, and one of them means you cannot currently take money at all.

Read the Critical section before you launch. Everything after it is a queue, not an emergency.

---

## What is genuinely good

Worth saying, because it is the reason the rest is fixable:

- **One service layer, two clients.** `order_service.php`, `review_service.php`, `wishlist_service.php` are called by both the website and the API. Business rules cannot drift between the two, which is the single most common failure in a project like this.
- **The webhook is the only place an order is marked paid.** The browser redirect is not trusted. That is the correct design and plenty of production systems get it wrong.
- **Payment ownership checks are server-side.** `can_review`, cart ownership, order ownership — the app renders verdicts, it does not compute them. A tampered client cannot review a shoe it never bought or read someone else's order.
- **Prices are re-read from the database at order time.** The app posts product ids and quantities; it cannot dictate what it is charged.
- **Idempotent, re-runnable infrastructure.** The SQL migration is guarded; the DSL script is guarded. You can re-run both without damage.

---

## Critical — fix before real customers

### 1. There is no password reset. At all.

```
grep -rlin "forgot|reset.password|password_reset" --include=*.php .   → no matches
grep -rln "mail(|PHPMailer|sendmail|smtp" --include=*.php .           → no matches
```

A customer who forgets their password is **permanently locked out**. There is no recovery flow on the website, none in the app, and no email capability to build one on. Your only remedy today is editing `users.password_hash` by hand in phpMyAdmin.

This will happen in your first week. It is the single most likely reason you will lose a real customer.

**Fix:** add SMTP (Hostinger includes mailboxes; PHPMailer over your own domain is the least-effort route), then a `password_resets` table with single-use, time-limited tokens, plus `forgot-password.php` and a matching API action. Budget half a day.

### 2. No transactional email of any kind

The same finding, wider consequences. Today:

- A customer who orders gets **no confirmation email**. Their only record is the app's Confirmed screen.
- Your contact form replies *"we will reply by email"* — but nothing sends one, and the admin only sees messages in a dashboard nobody is paged about.
- Order status changes notify in-app only. A customer who has closed the app learns nothing.

For a store taking real money and real delivery addresses, silence after payment reads as a scam. Order confirmation is the minimum.

### 3. PayMongo is in test mode — you cannot take money

`config/paymongo_keys.php` holds `sk_test_` / `pk_test_`. Every payment so far has been simulated.

Going live is a four-step change, and **three of the four are easy to forget**:

1. Swap to live keys
2. Register a **live-mode** webhook — test and live webhooks are entirely separate; this cost us hours already
3. Swap `PAYMONGO_WEBHOOK_SECRET` to the live hook's secret
4. Re-test the full flow with a real ₱20 order

Miss step 2 or 3 and every real order sits `unpaid` forever, exactly as they did before.

### 4. Stock can be oversold

```php
function product_decrement_stock(int $productId, int $qty): void {
    $stmt = db()->prepare('UPDATE products SET stock = GREATEST(stock - ?, 0) WHERE id = ?');
```

`order_create()` never checks that `stock >= qty` before writing the order, and there is no `SELECT ... FOR UPDATE` on the product row. Two people buying the last pair at the same moment both succeed; stock floors at zero and you are short one pair.

`GREATEST(..., 0)` hides the problem rather than preventing it — it guarantees you never see negative stock, which is exactly the signal you would want.

**Fix:** inside the existing transaction, lock and verify:

```sql
SELECT stock FROM products WHERE id = ? FOR UPDATE
-- then throw if stock < qty, before inserting the order
```

### 5. Login has no rate limiting

Five bad passwords in a row, as fast as curl can send them:

```
401 401 401 401 401
```

No delay, no lockout, no captcha — on both `api/auth.php?action=login` and `admin/login.php`. The admin panel is the serious one: it is a public URL protecting your entire product catalogue, customer list and order history behind one password.

**Fix:** a `login_attempts` table keyed on IP and username, an exponential delay after three failures, a lockout after ten. An hour's work.

---

## Important — fix soon

### 6. Sizes are not real inventory

This is the biggest *domain* gap, and it is specific to selling shoes.

Sizes exist on cart lines and order lines, but `products.stock` is a single number. Selling a US 7 decrements the same pool as a US 12. So the system will happily sell you eleven pairs of a shoe you only have in one size, and it can never answer "is US 9 in stock?"

Today's cart even has a comment acknowledging it clamps both sizes against one pool. For a shoe store this is the difference between a demo and a business.

**Fix:** a `product_sizes` table (`product_id`, `size`, `stock`), with `products.stock` becoming a derived total. It touches the cart, checkout, admin product screens and the app's size picker — a day's work, and it gets more expensive the longer real orders accumulate.

### 7. Guest orders are unreachable forever

Guest checkout writes `orders.user_id = NULL`. Order lookup requires ownership. Nobody — not even the customer who placed it — can ever retrieve a guest order through the API.

You accepted this trade knowingly, and it is the right call over leaving order data open. But the current state is that guest checkout produces an order the customer cannot see. Either require sign-in to check out, or add an order-number + email lookup.

### 8. Reviews publish instantly with no moderation

```php
INSERT INTO product_reviews (..., status) VALUES (?, ?, ?, ?, "approved")
```

Your admin has a review moderation screen, and `review_set_status()` supports `pending`. Nothing uses it — every review goes live the moment it is posted. Verified-purchase-only limits the blast radius, but one angry customer publishes straight to your product page.

**Fix:** default to `pending` and approve from the admin screen you already built. A one-word change plus a habit.

### 9. PHP executes inside `uploads/`

Four stray copies of site pages are live and executing there:

```
uploads/contact.php          200
uploads/index.php            200
uploads/login.php            200
uploads/includes/header.php  200
```

These are **old duplicate versions of your application** running in production. They will not receive your security fixes, and `uploads/login.php` is a second, stale front door to authentication.

Upload validation is extension-whitelist plus a forced rename (`uniqid('prod_').$ext`), which is why this is Important rather than Critical — an attacker cannot land a `.php`. But there is no content verification (`getimagesize`, MIME sniffing), and an uploads directory that executes PHP is a failure of defence in depth.

**Fix:** delete the four stray files, then drop an `.htaccess` into `uploads/` with `php_flag engine off`. Ten minutes.

### 10. Missing security headers

One of four present on the storefront. No Content-Security-Policy, no X-Frame-Options, no X-Content-Type-Options. Cheap to add in `.htaccess` and each closes a real class of attack.

---

## Worth doing

| | |
|---|---|
| **No push notifications** | Notifications are in-app only. A status change never reaches a closed app. Needs Firebase, a `device_tokens` table and a send hook — a real feature, not a config toggle. |
| **Shop search debounces at 2000 ms** | Two seconds before results move reads as broken. 300–400 ms is the norm. One value. |
| **Session cart is per-browser** | Signed-out web carts vanish when the session dies. Fine, but know that "add to cart, come back tomorrow" fails for guests. |
| **API token lifetime** | Governed by `API_TOKEN_TTL_DAYS`; expired-token cleanup runs only when someone logs in. A dormant table grows. Consider a cron. |
| **No order-cancel path for customers** | Admin can cancel; a customer cannot. Expect support messages instead. |
| **`checkout_session_id` is stored but never reused** | You could recover a stuck payment by re-querying PayMongo instead of replaying webhooks by hand. |

---

## Engineering practice — the honest part

The code is better than the process around it. This is what I would push hardest on if I were reviewing you on a team:

**There is no version control.** Not on the PHP, not on the DSL. `flutter workspace/server-patch/` is the only copy of the server source, and it is a folder on one laptop synced to OneDrive. Today the recovery story for a bad File Manager click is a backup I took by hand on 8 September. `git init`, one commit, one private remote. Twenty minutes, and it retires an entire category of disaster.

**There is no staging.** Every change edits production directly — including the day we were rewriting the checkout and the webhook. It worked out. It reliably will not, forever. Hostinger subdomains are free; a `staging.` copy pointed at a second database costs an afternoon and lets you break things safely.

**There are no tests.** One shell script (`smoke_cart.sh`) covers the cart. Nothing covers order creation, payment, auth or stock. You do not need a test pyramid — you need five smoke tests hitting the endpoints that move money, run before every deploy. You already have the pattern.

**Deploys are manual file uploads.** No record of what changed, no rollback beyond re-uploading an older file you hopefully kept. Version control fixes most of this on its own.

**The FlutterFlow DSL script is now ~2,300 lines in one function.** It works and it is re-runnable, but it will become hard to reason about. Worth splitting into per-feature functions.

---

## What I would do next, in order

1. **`git init` and push to a private remote** — twenty minutes, retires the worst risk you carry
2. **SMTP + password reset + order confirmation email** — the gap most likely to cost you a customer
3. **Stock check with row locking** — before you have enough traffic for it to bite
4. **Login rate limiting** — an hour, protects the admin panel
5. **Delete the stray `uploads/*.php` and disable PHP there** — ten minutes
6. **Per-size stock** — the real feature gap, and it only gets more expensive
7. **Then go live on PayMongo**, with all four switchover steps written down

---

## One closing note

The instinct that produced this — the app and the site sharing one cart, one price calculation, one set of business rules instead of two implementations that slowly disagree — is the right instinct, and it is the hard part. What is missing is mostly the unglamorous operational layer: recovery, notification, correctness under contention, and the ability to undo a mistake.

That layer is what separates something that demos well from something you can run. It is also, fortunately, the part you can add in about a week.
