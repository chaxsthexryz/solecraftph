<?php
require __DIR__ . '/../bootstrap.php';
require_method('GET');

$productId = (int) ($_GET['product_id'] ?? 0);
if ($productId <= 0) {
    json_error('A valid product_id is required.', 400);
}

$reviews = db_guard(function () use ($pdo, $productId) {
    $stmt = $pdo->prepare(
        'SELECT r.id, r.product_id, r.user_id, r.rating, r.comment, r.created_at,
                COALESCE(u.full_name, u.username) AS reviewer
           FROM product_reviews r
           LEFT JOIN users u ON u.id = r.user_id
          WHERE r.product_id = :pid AND r.status = "approved"
          ORDER BY r.created_at DESC'
    );
    $stmt->execute([':pid' => $productId]);
    return $stmt->fetchAll();
});

$reviews = array_map(static function (array $r): array {
    $r['id']       = (int) $r['id'];
    $r['product_id'] = (int) $r['product_id'];
    $r['user_id']  = $r['user_id'] !== null ? (int) $r['user_id'] : null;
    $r['rating']   = (int) $r['rating'];
    return $r;
}, $reviews);

json_ok(['reviews' => $reviews, 'count' => count($reviews)], null, 200);
