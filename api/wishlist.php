<?php
require __DIR__ . '/bootstrap.php';
require_method('GET');

$user = require_auth($pdo);

$items = db_guard(function () use ($pdo, $user) {
    $stmt = $pdo->prepare(
        'SELECT w.id AS wishlist_id, w.created_at AS added_at,
                p.id, p.name, p.category, p.subcategory, p.price, p.sale_price,
                p.stock, p.badge, p.image
           FROM wishlists w
           JOIN products p ON p.id = w.product_id
          WHERE w.user_id = :uid AND p.is_active = 1
          ORDER BY w.created_at DESC'
    );
    $stmt->execute([':uid' => (int) $user['id']]);
    return $stmt->fetchAll();
});

$items = array_map(static function (array $p): array {
    $p['wishlist_id'] = (int) $p['wishlist_id'];
    $p['id']          = (int) $p['id'];
    $p['price']       = (float) $p['price'];
    $p['sale_price']  = $p['sale_price'] !== null ? (float) $p['sale_price'] : null;
    $p['stock']       = (int) $p['stock'];
    $p['on_sale']     = $p['sale_price'] !== null;
    $p['image']       = absolute_image($p['image']);
    return $p;
}, $items);

json_ok(['wishlist' => $items, 'count' => count($items)], null, 200);
