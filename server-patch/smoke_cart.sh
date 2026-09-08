#!/usr/bin/env bash
# Cart-sync smoke test. Run AFTER uploading and running the SQL.
#   ./smoke_cart.sh <username> <password>
# Fails loudly if the shared cart isn't actually shared.
set -u
BASE="https://snow-jellyfish-553645.hostingersite.com"
U="${1:?username}"; P="${2:?password}"
fail() { echo "FAIL: $*"; exit 1; }

TOKEN=$(curl -s -X POST "$BASE/api/auth.php?action=login" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$U\",\"password\":\"$P\"}" \
  | grep -oE '"token":"[^"]+"' | cut -d'"' -f4)
[ -n "$TOKEN" ] || fail "no token from api/auth.php?action=login"

# Pick a product that is actually in stock. cart_add() ignores out-of-stock
# items on purpose, so a hardcoded id silently tests nothing the day it sells out.
PID=""
while IFS= read -r line; do
  id=$(printf '%s' "$line" | grep -oE '"id":[0-9]+' | head -1 | cut -d: -f2)
  stock=$(printf '%s' "$line" | grep -oE '"stock":[0-9]+' | head -1 | cut -d: -f2)
  if [ -n "$id" ] && [ -n "$stock" ] && [ "$stock" -ge 3 ]; then PID="$id"; break; fi
done < <(curl -s --max-time 30 "$BASE/api/products.php" | sed 's/},{/}\n{/g')
[ -n "$PID" ] || fail "no product with stock >= 3 to test with"
echo "Testing with product_id=$PID"

A="Authorization: Bearer $TOKEN"
curl -s -X POST "$BASE/api/cart.php?action=clear" -H "$A" >/dev/null

# Same shoe, two sizes -> must survive as TWO lines, not one.
curl -s -X POST "$BASE/api/cart.php?action=add" -H "$A" -H 'Content-Type: application/json' \
  -d "{\"product_id\":$PID,\"size\":\"9\",\"qty\":2}" >/dev/null
curl -s -X POST "$BASE/api/cart.php?action=add" -H "$A" -H 'Content-Type: application/json' \
  -d "{\"product_id\":$PID,\"size\":\"10\",\"qty\":1}" >/dev/null

BODY=$(curl -s "$BASE/api/cart.php" -H "$A")
echo "$BODY"
LINES=$(echo "$BODY" | grep -oE '"product_id":' | wc -l)
COUNT=$(echo "$BODY" | grep -oE '"count":[0-9]+' | cut -d: -f2)
[ "$LINES" -eq 2 ] || fail "expected 2 cart lines (size 9 and 10), got $LINES"
[ "$COUNT" -eq 3 ] || fail "expected count 3, got $COUNT"

# Dropping one size must leave the other alone.
curl -s -X POST "$BASE/api/cart.php?action=remove" -H "$A" -H 'Content-Type: application/json' \
  -d "{\"product_id\":$PID,\"size\":\"9\"}" >/dev/null
COUNT=$(curl -s "$BASE/api/cart.php" -H "$A" | grep -oE '"count":[0-9]+' | cut -d: -f2)
[ "$COUNT" -eq 1 ] || fail "expected count 1 after removing size 9, got $COUNT"

# Merge is a union, not a replace: the size-10 line must survive.
curl -s -X POST "$BASE/api/cart.php?action=merge" -H "$A" -H 'Content-Type: application/json' \
  -d "{\"items\":[{\"product_id\":$PID,\"size\":\"7\",\"qty\":1}]}" >/dev/null
BODY=$(curl -s "$BASE/api/cart.php" -H "$A")
LINES=$(echo "$BODY" | grep -oE '"product_id":' | wc -l)
[ "$LINES" -eq 2 ] || fail "merge should have added size 7 alongside size 10, got $LINES lines: $BODY"

echo "PASS — sizes kept apart, merge unions, cart is on the account."
echo "Now log in at $BASE/login.php as $U: cart.php must show US 10 x1 and US 7 x1."
