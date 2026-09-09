# Pin on Google Maps, Shopee-style

**Written:** 9 September 2026
**Status:** plan only — nothing built yet
**Scope:** a real map picker at checkout and in Delivery Addresses, plus the UI
cleanup those two screens need anyway

---

## What you asked for

1. **A Google map you can pin**, at checkout and in profile → Delivery Addresses
2. **The pin autofills the blanks** — drop it, get the address text
3. **Fix the UIs in there** so they match the rest of the app
4. **Shopee's flow**, specifically

Shopee's flow is worth naming exactly, because it is the spec:

> Tap the address field → a map opens full-bleed with a pin **fixed dead centre**
> → you drag the *map*, not the pin → a card at the bottom shows the address it
> resolved to, updating as you drag → **Confirm** → back on the form, with the
> address line filled and the coordinates attached.

The pin never moves. The map moves under it. That one detail is most of why it
feels good, and it is also what makes it cheap to build — no marker dragging, no
hit testing, just a centred icon painted over a map.

---

## Where this stands today

You already have the back half of this. `upgrade_v9_order_pin.sql` put
`latitude`/`longitude` on both `addresses` and `orders`, `address_public()` hands
back a ready-made `map_url`, and admin's order view opens it. The rider side is
done.

What's missing is the front half. Right now "Use my current location" is a button
that calls `Geolocator.getCurrentPosition()` and stores whatever it gets:

```dart
Future<String> currentPin() async {
  ...
  return '${position.latitude},${position.longitude}';
}
```

Three problems with that, in order of how much they matter:

1. **You cannot see it.** There is no map. The customer taps a button, gets
   "Location pinned", and has to take it on faith. If the phone put them two
   streets over — indoors, that is routine — nobody finds out until the rider is
   lost.
2. **You cannot correct it.** Ordering to your mother's house means the pin is
   wrong by definition, and there is no way to move it.
3. **It fills nothing in.** The coordinates ride *alongside* the typed address.
   That was a deliberate call at the time and it is still right as a fallback,
   but "pin it and the blanks fill themselves" is what you asked for.

So: keep `currentPin()` as the opening move — it is what centres the map the
first time — and build the map on top of it.

---

## The shape of it

One component, shown from both screens, writing to two app-state strings.

```
  ┌─ addresses page ─┐        ┌─ checkout page ─┐
  │  [Pin on map]    │        │  [Pin on map]   │
  └────────┬─────────┘        └────────┬────────┘
           └────────────┬──────────────┘
                        ▼
              ShowBottomSheet(pinSheet)      ← awaits until dismissed
                        │
                 ┌──────┴───────┐
                 │  PinMap      │  custom widget, google_maps_flutter
                 │  ⌖ centre    │  camera idle → reverse geocode
                 └──────┬───────┘
                        │ writes
                        ▼
              AppState.draftPin      "14.5995,120.9842"
              AppState.draftPinText  "123 Rizal St, Barangay ..."
                        │
                        ▼  (sheet closes, chain continues)
              SetFormField(addrLine, AppState.draftPinText)
              SetState(pin,          AppState.draftPin)
```

**Why a bottom sheet and not a page.** `ShowBottomSheet` compiles to an awaited
`showModalBottomSheet`, so the actions *after* it in the chain run when the sheet
closes. That gives us the return value a `Navigate.to` would not — there is no
"navigate and await result" in the DSL. It also means one component serves both
screens instead of a page that has to know who called it.

⚠️ **This is the load-bearing assumption of the whole design.** First thing I'll
do is a dry run to confirm the generated code really is
`await showModalBottomSheet(...)` and not fire-and-forget. If it isn't, the
fallback is an inline expandable map section on each screen — same widget, same
app state, one more copy of the confirm button.

**Why app state and not a callback.** Custom widget callbacks in this SDK are
`ActionType` with zero arguments (`ActionCallbackKind.onTap` and friends) — they
can fire, but they cannot carry a latitude back. Two app-state strings are the
documented way across that boundary, and they are plain strings, so they dodge
the list-of-struct declaration trap that `taxonomy` had to be worked around for.

---

## Row 1 — The Google Maps key

`app.ensureGoogleMaps(androidKey: secretRef('GMAPS_ANDROID_KEY'))`. The SDK has
first-class support for this, and `ensureGoogleMaps` is the idempotent variant,
so a rerun won't throw the way `googleMaps` would.

**The money question, honestly:** you need a Google Cloud project with **Maps SDK
for Android** enabled, and enabling it requires a billing account with a card
attached. Google has historically not metered map *displays* on the mobile SDKs
the way it meters the web and static APIs — but they restructured the pricing
tiers in 2025 and I am not going to state today's terms as fact from memory.
**Check the console's pricing page before you attach the card.** At your order
volume I would expect this to sit inside the free allowance either way, but that
is my expectation, not a guarantee, and you asked about paying once already.

**If you would rather not attach a card at all**, say so and I'll build the exact
same screen on `flutter_map` with OpenStreetMap tiles: no key, no billing
account, no signup. It is not Google's basemap and Philippine side streets are
patchier on OSM, but the flow, the pin, the drag and the autofill are identical,
and swapping the basemap later is a one-widget change. Your call — I'll default
to Google because that is what you asked for.

---

## Row 2 — The `PinMap` custom widget

`app.customWidget('PinMap', ...)` over `google_maps_flutter`. Roughly sixty
lines:

- `GoogleMap` with `initialCameraPosition` from the `startPin` parameter
- A centred `Icon` in a `Stack` over it — that's the whole "pin" (`IgnorePointer`,
  so drags reach the map)
- `onCameraMove` → nothing but a local setState for a small lift animation
- `onCameraIdle` → take the visible region's centre, write `FFAppState().draftPin`,
  then reverse geocode

**Reverse geocoding uses the `geocoding` package, not Google's Geocoding API.**
`placemarkFromCoordinates()` goes through Android's own `Geocoder`, which is free
and needs no key. Composing `street`, `subLocality`, `locality` and
`administrativeArea` gives a Philippine address line that reads correctly. It is
occasionally coarser than Google's paid endpoint, and it returns nothing at all
on a device without Play Services — both survivable, because the customer can
still type over whatever lands in the box.

**Debounced.** Reverse geocoding on every camera frame would hammer the platform
channel and flicker the label. Fires on idle only, with a 400 ms guard on top.

`ponytail: geocoding via platform Geocoder, upgrade to Google's Geocoding API
only if PH results come back too coarse to use.`

---

## Row 3 — The `pinSheet` component

`app.component('pinSheet', ...)` — a local component, which is what
`ShowBottomSheet` requires.

- 70% height, `enableDrag: false` (dragging the sheet and dragging the map fight
  each other otherwise)
- `PinMap` filling it
- A card floating at the bottom: the resolved address in `titleSmall`, the
  coordinates in `bodySmall` `secondaryText`, and a full-width **Use this
  location** button — 52px, radius 12, the same button as everywhere else
- A **Recentre** icon button over the map's bottom-right that re-calls
  `currentPin()`, because once you have dragged away there is no way back

Takes one param, `startPin`, so the sheet opens on the address being edited
rather than always on the phone's position.

---

## Row 4 — Wiring both screens

**Addresses page.** Replace "Use my current location" with **Pin on map**,
secondary style. `currentPin()` still runs first — it is what gives the sheet
somewhere sensible to open — but a failure is no longer a dead end, because the
sheet opens on Manila and you drag from there. Strictly better than today's
"could not get your location, you can still type".

```
onTap: [
  RequestPermissions(location),        // stays — from the last pass
  CallCustomAction(currentPin, outputAs: 'here'),
  ShowBottomSheet(pinSheet, params: {'startPin': ActionOutput('here')}),
  SetFormField(addrLine, AppState.draftPinText),   // ← runs on dismiss
  SetState(pin,          AppState.draftPin),
]
```

Note the nesting: there is no `ApiCall` in this chain, so the actions really are
siblings and really do run in order. The moment an API call goes in here, the
usual trap applies.

**Checkout.** Same button, same sheet, writing into `TextField_bng08kxc` and the
existing `pickedLat`/`pickedLng` page state that `CreateOrderPinned` already
reads. No server change: the pin has had a home on the order since v9.

---

## Row 5 — The UI fixes

You said "fix the UIs in there match the style". Here is what is actually wrong,
having read both screens:

| What | Now | Should be |
|---|---|---|
| Form fields | Bare `TextField`s — no fill, no border, no radius | White fill, `alternate` 1px border, radius 12 — the app's field |
| Two black buttons | "Use my current location" and "Save address" are both full-width primary, stacked, competing | Pin is secondary (outlined); Save is the only primary |
| The form | Always expanded under a `Divider()`, pushing the saved list off-screen | Collapsed behind **+ Add address**; `formOpen` state **already exists and is never read** — built for this and left unwired |
| Card actions | "Make default" / "Delete" as bare 6px-padded text | Icon + label, 44px tap targets, Delete in `error` only on confirm |
| **Edit** | **Missing entirely.** `editingId` is read on save and reset to 0 after, but nothing ever sets it to a real id — so a typo means delete and retype | An Edit action that loads the row into the form and sets `editingId` |
| Checkout chips | `addressPickerChip` is a fixed `secondaryBackground` — the picked one doesn't highlight | A selected variant, exactly like the category chips and size tiles just fixed |
| Pin state | Text reading "Location pinned" | The address it resolved to, or a static map thumbnail |

The Edit gap and the chip highlight are the two I'd call bugs rather than polish.

---

## Row 6 — The website (optional, say if you want it)

`addresses.php` and `checkout.php` would take the same treatment with the Maps
**JavaScript** API — same centred-pin trick, same fields. That *is* metered per
map load, unlike the mobile SDKs, so it is a genuinely separate cost decision.

Not included in the estimate below. The app works without it, and the website
keeps its typed addresses.

---

## Order, and what it costs

| # | Row | Depends on | Rough |
|---|---|---|---|
| 1 | Google Maps key + billing decision | **you** | 20 min |
| 2 | `PinMap` custom widget | 1 | 2 h |
| 3 | `pinSheet` component | 2 | 1 h |
| 4 | Wire addresses + checkout | 3 | 1 h |
| 5 | UI fixes + Edit + chip highlight | — | 2 h |
| 6 | Website parity | 1 | 2 h, optional |

Rows 2–5 are one DSL pass and one FlutterFlow commit. Row 5 doesn't depend on the
map and can ship first if you want something visible today.

**Row 1 is yours and blocks everything.** Two answers needed:

- **Google or OpenStreetMap?** Google needs a card on file; OSM needs nothing.
- **Website too, or app only?**

---

## What can't be verified from here

The map, the drag, the geocoder and the location permission are all things only a
real phone can prove — same standing item as the push notifications. I'll build it
so a total geocoder failure degrades to "the pin is saved, type the address
yourself", which is exactly where you are today, so a bad build is never worse
than no build.
