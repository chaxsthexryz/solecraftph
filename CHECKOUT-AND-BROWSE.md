# Browsing, search, and the payment flow

**Written:** 9 September 2026
**Status:** plan only — nothing built
**Method:** read the generated Dart, and probed the live API. Every claim below names where it came from.

---

## The short version

You named three things. All three are real, all three are app-side only — **the server already does everything needed for every one of them.** No new endpoints, no schema changes, no migrations.

While checking them I found four more in the same flow, and one of them is the reason the other ones matter.

---

## The one that costs you money

Your own order history, from the live API:

| Method | Payment status | Count |
|---|---|---|
| GCASH | **unpaid** | 14 |
| CARD | **unpaid** | 8 |
| GCASH | paid | 4 |
| COD | unpaid (correct — paid on delivery) | 4 |

**22 of 26 online orders were never paid.** Some of those are your own testing. But the flow makes it the default outcome, and here is why.

### The Done button doesn't check anything

`dsl/edit.dart` — the Payment screen's button:

```dart
Button('Done — view my order',
  onTap: Navigate.to(ff.Pages.confirmed, params: {'orderId': PageParam('orderId')}),
)
```

That is the whole action. It navigates. It does not ask PayMongo, or your server, whether a peso moved. A customer can open the payment screen, not pay, tap **Done**, and land on:

> **Thank you!**
> Your order has been placed on SoleCraftPH.

The screen is telling them the transaction succeeded. It has no idea whether it did.

### The app cannot tell paid from unpaid

`OrderRow` — the struct the confirmation screen binds to — has nine fields:

```
created_at, customer_address, customer_email, customer_name,
customer_phone, id, payment_method, status, total_amount
```

No `payment_status`. The API **does** send it — order 47 comes back `"payment_status":"unpaid"` — the app just never declared the field, so it cannot read it. The "Status" row on the confirmation screen shows `status` instead, which is the *fulfilment* status (pending, shipped, delivered), a different thing entirely.

So the app is not lying on purpose. It genuinely cannot tell.

### The back button lets them return to a finished order

`confirmed_widget.dart:78`

```dart
automaticallyImplyLeading: true,
```

The confirmation screen keeps its back arrow, so the whole payment flow stays on the navigation stack. Back goes to the PayMongo WebView for an order already placed, and back again to a Checkout form whose bag is now empty.

### The bag is emptied before payment

In the place-order chain:

```dart
UpdateAppState.set(ff.AppState.lastOrderId, res['id']),
ClearAppState(ff.AppState.bag),        // ← runs for GCash and Card too
If(Equals(res['checkout_url'], ''), ...)
```

The bag is cleared the moment the order record is created — before PayMongo has even been opened. Abandon the payment and you have an unpaid order *and* an empty bag, and you rebuild your whole basket to try again. That is very likely part of why 22 orders died unpaid.

### What it should do instead

The webhook already works — it flips orders to paid, and it settled order 41 autonomously. Nothing needs building server-side. The app needs to:

1. Add `payment_status` to `OrderRow`
2. Clear the bag only when an order is COD, or when payment is confirmed
3. Replace the Payment screen's Done button with **"I've paid — check"**, which re-reads the order and only moves on when `payment_status` is `paid`; if it isn't, say so and stay put
4. Make the confirmation screen say different things for paid, unpaid-online and COD, instead of "Thank you!" unconditionally
5. Drop the back arrow on confirmation and make it a "Continue shopping" route that resets the stack

**Half a day.** This is the one I'd do first.

---

## Search: the box works, the wiring races

From `shop_widget.dart`:

```dart
onChanged: (_) => EasyDebounce.debounce(
  '_model.shopSearchFieldTextController',
  Duration(milliseconds: 2000),          // ← two seconds
  () async { _model.search = _model.shopSearchFieldTextController.text; },
),
onFieldSubmitted: (_) async {
  _model.shopSearch = await ApiGroup.getProductsCall.call(
    q: _model.search,                    // ← the debounced copy, not the box
  );
```

Type `brooks`, hit search in under two seconds — which is everyone — and `_model.search` still holds the **previous** value. On a first search that is an empty string, so the API is asked for everything and the list appears not to filter. Search a second time and you get results for what you typed the *first* time.

The endpoint is fine: `/api/products.php?q=brooks` returns exactly 1 product.

**Fix:** read the controller directly on submit, and cut the debounce to ~350ms so typing filters live. **Under an hour.**

---

## Categories: the drill-down is missing

Your website does two levels. Picking a category reveals a second row:

```
/index.php?category=Athletic+%26+Performance+Footwear
   → &subcategory=Road+Running+Shoes
   → &subcategory=Trail+Running+Shoes
   → &subcategory=Training+%26+Gym+Shoes
```

The app has three fixed top-level chips and stops there. There is no subcategory anywhere in it.

The API already accepts both — `?category=…&subcategory=Road Running Shoes` returns 5 products — so this is purely a UI addition: a second chip row that appears once a category is chosen, clears when you switch category, and passes `subcategory` through to the same call the chips already make.

`PRODUCT_TAXONOMY` (three categories, three subcategories each) is a PHP constant, so the honest version reads the pairs from the server rather than hardcoding nine strings the way the current three are hardcoded. `/api/settings.php` already returns the category list and can return the subcategory map alongside it.

**Half a day**, including a small server change to send the taxonomy.

---

## Also found while stress-testing

### Guest checkout produces a broken confirmation screen

Nothing gates checkout on being signed in:

```dart
onPressed: () async { context.pushNamed(CheckoutWidget.routeName); },
```

The server allows a guest order — `user_id` is nullable, same as the website. But the confirmation screen then calls `GetOrder` with an empty token, and:

```
GET /api/orders.php?id=47  (no token)  →  HTTP 401
```

So a guest places a real order, is charged, and lands on a confirmation screen with no order number, no amount, no status. The order exists; they have no way to see it, then or ever, because My Orders needs an account.

**Either** require sign-in before checkout (simplest, matches where the app is going), **or** let the confirmation screen fall back to what the create-order response already returned. I would require sign-in.

### The two known ones, still open

- **Push notifications** — the Enable toggle needs turning **off**. The generated helper imports `cloud_firestore`, which isn't in the build, so the app won't compile while it's on.
- **Privacy policy** is still placeholder text.

---

## What I would do, in order

| | Work | Effort |
|---|---|---|
| 1 | Payment confirmation: `payment_status`, real Done button, honest confirmation screen, no back arrow, bag cleared only when it should be | ~4 hrs |
| 2 | Search: read the controller on submit, debounce 2000 → 350ms | ~1 hr |
| 3 | Require sign-in before checkout | ~30 min |
| 4 | Subcategory chips, taxonomy from the server | ~4 hrs |

1 and 2 are the ones customers are hitting today. 3 is small and closes a hole that produces unreachable orders. 4 is the feature you asked for and the least urgent of the four.

Say the word and I'll start at the top.

---

## Parked, at your request

Autofill, saved addresses (Home/Work), and GPS — written up separately in `SHIPPING-ADDRESSES.md`. The autofill half of that is a 30-minute bug fix whenever you want it: checkout already loads the customer's saved details into page state and then renders four empty boxes that never read them.
