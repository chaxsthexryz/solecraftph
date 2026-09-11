<?php
require_once __DIR__ . '/config/app.php';
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/cart.php';
require_once __DIR__ . '/includes/order_service.php';
require_once __DIR__ . '/includes/settings_service.php';
require_once __DIR__ . '/includes/notification_service.php';

$items = cart_items();
$error = '';

// Prefill from the logged-in account so a returning customer doesn't
// retype what's already on their profile. $_POST wins on a failed
// resubmit so we don't clobber what they just typed.
$currentUser = auth_is_logged_in() ? auth_current_user() : null;

// Saved addresses, and whichever one this checkout is using. A customer who
// has saved "Work" should not have to retype it, and picking it must not cost
// them the pin their phone attached to it.
require_once __DIR__ . '/includes/address_service.php';
$savedAddresses = $currentUser ? address_list((int) $currentUser['id']) : [];
$chosenId = (int) ($_POST['address_id'] ?? $_GET['address'] ?? 0);
$chosen = null;
foreach ($savedAddresses as $sa) {
    if ($chosenId > 0 && (int) $sa['id'] === $chosenId) { $chosen = $sa; break; }
}
// No explicit pick means the default, which address_list() sorts first.
if ($chosen === null && $chosenId === 0 && $savedAddresses) {
    $chosen = $savedAddresses[0];
}

$prefill = [
    'name'    => $_POST['name']    ?? (!empty($chosen['recipient_name']) ? $chosen['recipient_name'] : ($currentUser['full_name'] ?? '')),
    'email'   => $_POST['email']   ?? ($currentUser['email'] ?? ''),
    'phone'   => $_POST['phone']   ?? (!empty($chosen['phone']) ? $chosen['phone'] : ($currentUser['phone'] ?? '')),
    'address' => $_POST['address'] ?? ($chosen['address'] ?? ($currentUser['address'] ?? '')),
];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (empty($items)) {
        $error = 'Your cart is empty.';
    } else {
        $name    = trim($_POST['name'] ?? '');
        $email   = trim($_POST['email'] ?? '');
        $phone   = trim($_POST['phone'] ?? '');
        $address = trim($_POST['address'] ?? '');
        $payment = $_POST['payment_method'] ?? 'COD';
        $allowedPayments = array_keys(settings_enabled_payment_methods());
        if (!in_array($payment, $allowedPayments, true)) {
            $payment = $allowedPayments[0] ?? 'COD';
        }

        if ($name === '' || $email === '' || $phone === '' || $address === '') {
            $error = 'Please fill in all required fields.';
        } elseif (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $error = 'Please enter a valid email address.';
        } else {
            try {
                // The pin, when this order is going to a saved address that
                // has one. order_create stores both halves or neither.
                $orderId = order_create([
                    'user_id'        => $_SESSION['user_id'] ?? null,
                    'name'           => $name,
                    'email'          => $email,
                    'phone'          => $phone,
                    'address'        => $address,
                    'latitude'       => $chosen['latitude'] ?? '',
                    'longitude'      => $chosen['longitude'] ?? '',
                    'payment_method' => $payment,
                ], $items);

                order_update_status($orderId, 'pending', 'Order placed.');
                notification_notify_admins('New Order', 'Order #' . str_pad((string) $orderId, 6, '0', STR_PAD_LEFT) . ' placed by ' . $name . '.');
                if (!empty($_SESSION['user_id'])) {
                    notification_notify_customer((int) $_SESSION['user_id'], 'Order Placed', 'Your order #' . str_pad((string) $orderId, 6, '0', STR_PAD_LEFT) . ' has been received.');
                }

                if ($payment === 'GCASH' || $payment === 'CARD') {
                    // Online methods: don't clear the cart or call the order
                    // "placed" for the customer yet — the order stays
                    // payment_status='unpaid' until PayMongo's webhook
                    // confirms it. If PayMongo itself can't be reached,
                    // cancel the order rather than leave a live cart order
                    // with no way to ever get paid.
                    require_once __DIR__ . '/includes/paymongo_service.php';
                    $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
                    $origin = $scheme . '://' . $_SERVER['HTTP_HOST'];
                    try {
                        $session = paymongo_create_checkout_session(
                            $orderId,
                            $items,
                            settings_shipping_for(cart_total()),
                            [strtolower($payment)],
                            $origin . BASE_PATH . '/order_success.php?id=' . $orderId,
                            $origin . BASE_PATH . '/checkout.php'
                        );
                        order_set_checkout_session($orderId, $session['session_id']);
                        cart_clear();
                        header('Location: ' . $session['checkout_url']);
                        exit;
                    } catch (Throwable $paymentError) {
                        order_update_status($orderId, 'cancelled', 'Could not start PayMongo checkout: ' . $paymentError->getMessage());
                        $error = 'We couldn\'t start the payment step. Please try again, or choose Cash on Delivery.';
                    }
                } else {
                    cart_clear();
                    header('Location: ' . BASE_PATH . '/order_success.php?id=' . $orderId);
                    exit;
                }
            } catch (Throwable $e) {
                $error = 'Could not place your order: ' . $e->getMessage();
            }
        }
    }
}

$pageTitle = 'Checkout — SoleCraftPH';
require __DIR__ . '/includes/header.php';
?>

<header class="pagehead">
  <div class="wrap">
    <h1 class="display">Checkout</h1>
    <p>Fill in your delivery details to complete your order.</p>
  </div>
</header>

<section class="section">
  <div class="wrap checkout-layout" style="display:grid;grid-template-columns:1.4fr 1fr;gap:40px;align-items:start;">

    <div class="panel">
      <?php if ($error): ?><div class="alert alert--error"><?= htmlspecialchars($error) ?></div><?php endif; ?>
      <?php if (empty($items)): ?>
        <p>Your cart is empty. <a href="<?= BASE_PATH ?>/index.php" class="btn" style="margin-left:10px;">Shop Now</a></p>
      <?php else: ?>
        <?php if ($savedAddresses): ?>
          <div style="margin-bottom:20px;">
            <label class="mono" style="display:block;margin-bottom:8px;">Deliver to</label>
            <div style="display:flex;gap:8px;flex-wrap:wrap;">
              <?php foreach ($savedAddresses as $sa): ?>
                <?php $isOn = $chosen && (int) $chosen['id'] === (int) $sa['id']; ?>
                <a href="<?= BASE_PATH ?>/checkout.php?address=<?= (int) $sa['id'] ?>"
                   class="btn btn--sm<?= $isOn ? ' btn--solid' : '' ?>">
                  <?= htmlspecialchars($sa['label']) ?>
                </a>
              <?php endforeach; ?>
              <a href="<?= BASE_PATH ?>/addresses.php" class="btn btn--sm">Manage&hellip;</a>
            </div>
          </div>
        <?php endif; ?>

        <form method="post" action="<?= BASE_PATH ?>/checkout.php">
          <input type="hidden" name="address_id" value="<?= (int) ($chosen['id'] ?? 0) ?>">
          <div class="form-grid">
            <div class="form-field"><label>Full Name *</label><input type="text" name="name" required value="<?= htmlspecialchars($prefill['name']) ?>"></div>
            <div class="form-field"><label>Email *</label><input type="email" name="email" required value="<?= htmlspecialchars($prefill['email']) ?>"></div>
            <div class="form-field"><label>Phone *</label><input type="text" name="phone" required value="<?= htmlspecialchars($prefill['phone']) ?>"></div>
            <div class="form-field"><label>Payment Method</label>
              <select name="payment_method">
                <?php foreach (settings_enabled_payment_methods() as $code => $label): ?>
                  <option value="<?= htmlspecialchars($code) ?>"><?= htmlspecialchars($label) ?></option>
                <?php endforeach; ?>
              </select>
            </div>
            <div class="form-field full"><label>Delivery Address *</label><textarea name="address" required><?= htmlspecialchars($prefill['address']) ?></textarea></div>
          </div>
          <button type="submit" class="btn btn--solid" style="width:100%;justify-content:center;">Place Order</button>
        </form>
      <?php endif; ?>
    </div>

    <div class="cart-summary__box">
      <h3 class="display" style="font-size:24px;margin-bottom:16px;">Order Summary</h3>
      <?php foreach ($items as $item): ?>
        <div class="cart-summary__row"><span><?= htmlspecialchars($item['name']) ?> &times; <?= (int) $item['qty'] ?></span><span>₱<?= number_format($item['price'] * $item['qty'], 2) ?></span></div>
      <?php endforeach; ?>
      <div class="cart-summary__row"><span>Shipping</span><span><?= settings_shipping_for(cart_total()) == 0 ? 'Free' : '₱' . number_format(settings_shipping_for(cart_total()), 2) ?></span></div>
      <div class="cart-summary__row total"><span>Total</span><span>₱<?= number_format(cart_total() + ($items ? settings_shipping_for(cart_total()) : 0), 2) ?></span></div>
    </div>
  </div>
</section>

<?php require __DIR__ . '/includes/footer.php'; ?>
