<?php
require __DIR__ . '/bootstrap.php';
require_method('GET');

$user = require_auth($pdo);

$orders = db_guard(function () use ($pdo, $user) {
    $stmt = $pdo->prepare(
        'SELECT o.id, o.total_amount, o.status, o.payment_method,
                o.tracking_number, o.created_at,
                COUNT(oi.id) AS item_count,
                COALESCE(SUM(oi.quantity), 0) AS total_quantity
           FROM orders o
           LEFT JOIN order_items oi ON oi.order_id = o.id
          WHERE o.user_id = :uid
          GROUP BY o.id
          ORDER BY o.created_at DESC'
    );
    $stmt->execute([':uid' => (int) $user['id']]);
    return $stmt->fetchAll();
});

$orders = array_map(static function (array $o): array {
    $o['id']             = (int) $o['id'];
    $o['total_amount']   = (float) $o['total_amount'];
    $o['item_count']     = (int) $o['item_count'];
    $o['total_quantity'] = (int) $o['total_quantity'];
    return $o;
}, $orders);

json_ok(['orders' => $orders], null, 200);
