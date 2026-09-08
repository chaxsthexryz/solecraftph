<?php
require_once __DIR__ . '/config/app.php';
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/cart.php';
require_once __DIR__ . '/includes/settings_service.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action    = $_POST['action'] ?? '';
    $productId = (int) ($_POST['product_id'] ?? 0);
    $size      = (string) ($_POST['size'] ?? '');

    // JS sends this header so it can add-to-cart without leaving the
    // current page. Anyone posting here without it (no JS, old
    // clients) keeps getting the normal redirect-to-cart-page behavior.
    $isAjax = (isset($_SERVER['HTTP_X_REQUESTED_WITH']) && strtolower($_SERVER['HTTP_X_REQUESTED_WITH']) === 'xmlhttprequest')
        || (isset($_SERVER['HTTP_ACCEPT']) && stripos($_SERVER['HTTP_ACCEPT'], 'application/json') !== false);

    $ok      = true;
    $message = '';

    if ($action === 'add') {
        $qty     = max(1, (int) ($_POST['qty'] ?? 1));
        $product = product_find($productId);
        if (!$product) {
            $ok = false;
            $message = 'Product not found.';
        } elseif ($product['stock'] < 1) {
            $ok = false;
            $message = 'Sorry, that item is out of stock.';
        } elseif (cart_normalize_size($size) === '') {
            $ok = false;
            $message = 'Please choose a size first.';
        } else {
            cart_add($productId, $qty, $size);
            $message = htmlspecialchars($product['name']) . ' (US ' . htmlspecialchars($size) . ') added to cart.';
        }
    } elseif ($action === 'update') {
        $qty = (int) ($_POST['qty'] ?? 1);
        cart_update($productId, $qty, $size);
        $message = 'Cart updated.';
    } elseif ($action === 'remove') {
        cart_remove($productId, $size);
        $message = 'Item removed from cart.';
    }

    if ($isAjax) {
        header('Content-Type: application/json');
        echo json_encode([
            'ok'         => $ok,
            'message'    => $message,
            'cart_count' => cart_count(),
            'cart_total' => cart_total(),
        ]);
        exit;
    }
    header('Location: ' . BASE_PATH . '/cart.php');
    exit;
}

$items = cart_items();
$pageTitle = 'Your Cart — SoleCraftPH';
require __DIR__ . '/includes/header.php';
?>
<header class="pagehead">
  <div class="wrap">
    <h1 class="display">Your Cart</h1>
    <p><?= cart_count() ?> item(s) in your bag.</p>
    <?php if (!auth_is_logged_in()): ?>
      <p style="opacity:.75;font-size:14px;">
        <a href="<?= BASE_PATH ?>/login.php">Log in</a> to keep this bag on your account and see it in the app.
      </p>
    <?php endif; ?>
  </div>
</header>

<section class="section">
  <div class="wrap">
    <?php if (empty($items)): ?>
      <div class="empty-state">
        Your cart is empty.
        <div style="margin-top:20px;"><a href="<?= BASE_PATH ?>/index.php" class="btn btn--solid">Continue Shopping</a></div>
      </div>
    <?php else: ?>
      <div class="table-scroll">
      <table class="cart-table">
        <thead>
          <tr>
            <th>Product</th>
            <th>Size</th>
            <th>Price</th>
            <th>Quantity</th>
            <th>Subtotal</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <?php foreach ($items as $item): ?>
            <tr>
              <td><?= htmlspecialchars($item['name']) ?></td>
              <td><?= $item['size'] === '' ? '—' : 'US ' . htmlspecialchars($item['size']) ?></td>
              <td>₱<?= number_format($item['price'], 2) ?></td>
              <td>
                <form method="post" action="<?= BASE_PATH ?>/cart.php" style="display:flex;gap:8px;align-items:center;">
                  <input type="hidden" name="action" value="update">
                  <input type="hidden" name="product_id" value="<?= (int) $item['product_id'] ?>">
                  <input type="hidden" name="size" value="<?= htmlspecialchars($item['size']) ?>">
                  <input class="qty-input" type="number" name="qty" value="<?= (int) $item['qty'] ?>" min="1">
                  <button type="submit" class="btn btn--sm">Update</button>
                </form>
              </td>
              <td>₱<?= number_format($item['price'] * $item['qty'], 2) ?></td>
              <td>
                <form method="post" action="<?= BASE_PATH ?>/cart.php">
                  <input type="hidden" name="action" value="remove">
                  <input type="hidden" name="product_id" value="<?= (int) $item['product_id'] ?>">
                  <input type="hidden" name="size" value="<?= htmlspecialchars($item['size']) ?>">
                  <button type="submit" class="link-remove" style="background:none;border:none;cursor:pointer;">Remove</button>
                </form>
              </td>
            </tr>
          <?php endforeach; ?>
        </tbody>
      </table>
      </div>

      <div class="cart-summary">
        <div class="cart-summary__box">
          <div class="cart-summary__row"><span>Subtotal</span><span>₱<?= number_format(cart_total(), 2) ?></span></div>
          <div class="cart-summary__row"><span>Shipping</span><span><?= settings_shipping_for(cart_total()) == 0 ? 'Free' : '₱' . number_format(settings_shipping_for(cart_total()), 2) ?></span></div>
          <div class="cart-summary__row total"><span>Total</span><span>₱<?= number_format(cart_total() + settings_shipping_for(cart_total()), 2) ?></span></div>
          <a href="<?= BASE_PATH ?>/checkout.php" class="btn btn--solid" style="width:100%;justify-content:center;margin-top:18px;">Proceed to Checkout</a>
        </div>
      </div>
    <?php endif; ?>
  </div>
</section>

<?php require __DIR__ . '/includes/footer.php'; ?>
