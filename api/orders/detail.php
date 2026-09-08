<?php
require __DIR__ . '/../bootstrap.php';
require_method('GET');

$user = require_auth($pdo);
$id   = (int) ($_GET['id'] ?? 0);
if ($id <= 0) {
    json_error('A valid order id is required.', 400);
}

$order = db_guard(function () use ($pdo, $id, $user) {
    $stmt = $pdo->prepare(
        'SELECT id, user_id, customer_name, customer_email, customer_phone,
                customer_address, payment_method, total_amount, status,
                tracking_number, created_at, updated_at
           FROM orders
          WHERE id = :id
          LIMIT 1'
    );
    $stmt->execute([':id' => $id]);
    return $stmt->fetch();
});

if (!$order) {
    json_error('Order not found.', 404);
}
// Ownership check — customers may only see their own orders.
if ((int) $order['user_id'] !== (int) $user['id']) {
    json_error('You do not have access to this order.', 403);
}

$items = db_guard(function () use ($pdo, $id) {
    $stmt = $pdo->prepare(
        'SELECT id, product_id, product_name, unit_price, quantity, subtotal
           FROM order_items
          WHERE order_id = :id
          ORDER BY id ASC'
    );
    $stmt->execute([':id' => $id]);
    return $stmt->fetchAll();
});

$timeline = db_guard(function () use ($pdo, $id) {
    $stmt = $pdo->prepare(
        'SELECT status, note, created_at
           FROM order_status_log
          WHERE order_id = :id
          ORDER BY created_at ASC, id ASC'
    );
    $stmt->execute([':id' => $id]);
    return $stmt->fetchAll();
});

// Type normalisation.
$order['id']           = (int) $order['id'];
$order['user_id']      = $order['user_id'] !== null ? (int) $order['user_id'] : null;
$order['total_amount'] = (float) $order['total_amount'];
unset($order['user_id']);   // not needed by the client, already ownership-checked

$items = array_map(static function (array $i): array {
    $i['id']         = (int) $i['id'];
    $i['product_id'] = $i['product_id'] !== null ? (int) $i['product_id'] : null;
    $i['unit_price'] = (float) $i['unit_price'];
    $i['quantity']   = (int) $i['quantity'];
    $i['subtotal']   = (float) $i['subtotal'];
    return $i;
}, $items);

json_ok([
    'order'    => $order,
    'items'    => $items,
    'timeline' => $timeline,
], null, 200);
