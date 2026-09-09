# Shipping details: autofill, saved locations, GPS

**Written:** 9 September 2026
**Status:** plan only — nothing built yet
**Scope:** three related changes to how a customer gives you an address

---

## What you asked for

1. **Autofill** the shipping details at checkout
2. **Saved locations** — Home, Work, and so on, picked rather than retyped
3. **GPS** — "locate me" to fill the address from where the phone is

They stack in that order: each one is only worth doing once the one before it works. Below is what each actually costs, and the one decision that has money attached.

---

## Part 1 — Autofill is already half-built, and broken

This is not a new feature. It was wired up and never worked, and I'd fix it first regardless of the rest.

`checkout_widget.dart` page load:

```dart
_model.fullName = FFAppState().userFullName;
_model.email    = FFAppState().userEmail;
_model.phone    = FFAppState().userPhone;
_model.address  = FFAppState().userAddress;
```

Then, further down the same file:

```dart
_model.coNameTextController ??= TextEditingController();   // empty
_model.coEmailTextController ??= TextEditingController();  // empty
```

The page load fills four **page state** fields. The four boxes on screen are bound to **controllers** that start empty and never read those fields. So the state is set correctly and nothing appears — a signed-in customer retypes their name, email, phone and address on every order.

The data is definitely there: `userPhone` and `userAddress` are set on login and again whenever the profile is saved.

**The website already does this properly** (`checkout.php`):

```php
// Prefill from the logged-in account so a returning customer doesn't
// retype what's already on their profile.
$prefill = [
    'name'  => $_POST['name'] ?? ($currentUser['full_name'] ?? ''),
    ...
];
```

So this is the same shape of gap as the size picker: the website is right, the app is the odd one out.

**Fix:** bind each field's initial value to the app-state value instead of setting page state nothing reads. Four bindings, no new tables, no new screens, no server work. **Half an hour.**

---

## Part 2 — Saved locations

### What exists now

One address per customer, a single free-text block:

- `users.address` — one column, edited on the Profile screen
- `orders.customer_address` — the address copied onto the order at checkout

There is no concept of a second address anywhere, on the app or the website.

### What it needs

**A table.** Roughly:

| column | why |
|---|---|
| `id`, `user_id` | whose it is |
| `label` | "Home", "Work", or whatever they type |
| `recipient_name`, `phone` | deliveries to a parent or an office reception |
| `address` | one text block, matching how orders already store it |
| `latitude`, `longitude` | nullable, filled by Part 3 |
| `is_default` | which one checkout starts on |

Keeping the address as one text block matters: `orders.customer_address` is already a single field, so nothing downstream — the order emails, the admin order view, the receipt — has to change.

**An API.** `/api/addresses.php` — list, create, update, delete, set-default. Same bearer auth as everything else.

**Screens.** An Addresses screen (list, add, edit, delete, set default), a tile for it on Account, and a row of pickable labels on Checkout above the address box.

**Migration.** Every existing customer's `users.address` becomes their first saved address, labelled "Home", set as default. Nobody logs in to find their address gone.

**A decision:** does the website get this too, or does it stay one-address? If the app can save three addresses and the website still shows one box, the two drift — which is the exact problem we just spent two days closing. My recommendation is to do the app first, then mirror it on the website, and I would not call this finished until both are done.

**Roughly a day**, most of it the Addresses screen and the checkout picker.

---

## Part 3 — GPS

### How it works

Three steps, and only the third one costs anything:

1. **Ask permission.** Supported directly (`PermissionKind.location`).
2. **Read the coordinates.** Needs the `geolocator` package added to the build and a small custom action — the same pattern as the push token: FlutterFlow has no built-in for this, and the package is not in the build today.
3. **Turn coordinates into an address.** This is reverse geocoding, and it is where the money is.

### The one decision with a price on it

| | Cost | Quality | Notes |
|---|---|---|---|
| **Google Geocoding API** | Free monthly credit, **card on file required** | Best in the Philippines by a distance | Same billing setup you just declined for Blaze |
| **Nominatim (OpenStreetMap)** | Free, no card | Decent for cities, thin for rural barangays | Max ~1 request/second; must be called from our server, not the phone, to stay inside their usage policy |
| **No reverse geocoding** | Free | — | GPS saves the *pin*, the customer still types the address |

**My recommendation: the third one, then Nominatim if it isn't enough.**

Here is the reasoning. A Philippine delivery address is usually not something a geocoder can produce — it is "blk 12 lot 4, corner of the sari-sari store, ask for Nanay Beth". Reverse geocoding gives you a street and a barangay, which the customer then has to correct anyway. What actually helps the rider is the **pin**, and that costs nothing: store `latitude`/`longitude` on the address, show them on the admin order page as a Google Maps link, and let the customer type the address the way they'd say it out loud.

That gets you the useful 90% for free. If it turns out customers really do want the box filled in for them, adding Nominatim later is a small server-side change — `/api/geocode.php` taking a lat/lng and returning a formatted address — and does not change the data model, because `latitude` and `longitude` are already there.

**Half a day** for the coordinate capture and the admin map link. Another half day if you later add Nominatim.

---

## What I need from you

1. **Reverse geocoding** — go with pin-only (my recommendation), or do you want the address box auto-filled from the start?
2. **The website** — mirror saved addresses there too, or app-only for now? (App-only means known drift.)
3. **Scope** — all three parts, or stop after autofill and see how it feels?

---

## Suggested order

| | Work | Effort | Depends on |
|---|---|---|---|
| 1 | Fix autofill | ~30 min | nothing |
| 2 | `addresses` table + API + migration | ~3 hrs | nothing |
| 3 | Addresses screen + Account tile | ~3 hrs | 2 |
| 4 | Checkout picker | ~1 hr | 3 |
| 5 | GPS pin capture + admin map link | ~3 hrs | 2 |
| 6 | Website parity | ~3 hrs | 2 |

Step 1 stands alone and is worth doing whatever you decide about the rest — right now every signed-in customer retypes four fields they have already given you.

---

## Still outstanding from before this

Not part of this work, but not finished either:

- **Push notifications:** the Enable toggle needs turning **off** in FlutterFlow. The generated helper imports `cloud_firestore`, which is not in the build, so the app will not compile while it is on. Everything else for push is done and verified.
- **Privacy policy** is still placeholder text, and is the last thing between you and a Play Store submission.
