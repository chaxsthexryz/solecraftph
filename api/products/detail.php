<?php
require __DIR__ . '/../bootstrap.php';
require_method('GET');

$id = (int) ($_GET['id'] ?? 0);
if ($id <= 0) {
    json_error('A valid product id is required.', 400);
}

$product = db_guard(function () use ($pdo, $id) {
    $stmt = $pdo->prepare(
        'SELECT id, name, category, subcategory, description, price, sale_price,
                stock, low_stock_threshold, badge, image, created_at
           FROM products
          WHERE id = :id AND is_active = 1
          LIMIT 1'
    );
    $stmt->execute([':id' => $id]);
    return $stmt->fetch();
});

if (!$product) {
    json_error('Product not found.', 404);
}

// Aggregate review stats (approved only).
$stats = db_guard(function () use ($pdo, $id) {
    $stmt = $pdo->prepare(
        'SELECT COUNT(*) AS cnt, AVG(rating) AS avg_rating
           FROM product_reviews
          WHERE product_id = :id AND status = "approved"'
    );
    $stmt->execute([':id' => $id]);
    return $stmt->fetch();
});

$product['id']                  = (int) $product['id'];
$product['price']               = (float) $product['price'];
$product['sale_price']          = $product['sale_price'] !== null ? (float) $product['sale_price'] : null;
$product['stock']               = (int) $product['stock'];
$product['low_stock_threshold'] = (int) $product['low_stock_threshold'];
$product['on_sale']             = $product['sale_price'] !== null;
$product['image']               = absolute_image($product['image']);
$product['in_stock']            = $product['stock'] > 0;
$product['review_count']        = (int) ($stats['cnt'] ?? 0);
$product['average_rating']      = $stats['avg_rating'] !== null ? round((float) $stats['avg_rating'], 1) : null;

json_ok($product, null, 200);
