# Small edits — two files, one paste each

Everything else ships as a whole file; drop those in at the matching path.

## 1. `includes/auth.php` — carry a guest bag into the account on login

In `auth_attempt_login()`, right after `$_SESSION['role'] = $user['role'];`:

```php
        // Whatever they put in the bag while logged out follows them in.
        require_once __DIR__ . '/cart.php';
        cart_merge_session_into_account((int) $user['id']);
```

Same three lines at the end of `auth_register_customer()` if you log people in on signup.

## 2. Show size wherever order lines are listed

`order_detail.php:69`, `admin/admin_order_detail.php:109`, `admin/invoice.php:74` —
each has the same cell:

```php
<td><?= htmlspecialchars($item['product_name']) ?><?= !empty($item['size']) ? ' <small>(US ' . htmlspecialchars($item['size']) . ')</small>' : '' ?></td>
```

`checkout.php`'s order summary (line ~137) is the same idea:

```php
        <div class="cart-summary__row">
          <span><?= htmlspecialchars($item['name']) ?><?= $item['size'] !== '' ? ' (US ' . htmlspecialchars($item['size']) . ')' : '' ?> &times; <?= (int) $item['qty'] ?></span>
          <span>₱<?= number_format($item['price'] * $item['qty'], 2) ?></span>
        </div>
```
