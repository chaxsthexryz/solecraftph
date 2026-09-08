<?php
require __DIR__ . '/../bootstrap.php';
require_method('POST');

$user = require_auth($pdo);
$in   = body_input();

$productId = (int) ($in['product_id'] ?? 0);
$rating    = (int) ($in['rating'] ?? 0);
$comment   = input_str($in, 'comment');

if ($productId <= 0) {
    json_error('A valid product_id is required.', 400);
}
if ($rating < 1 || $rating > 5) {
    json_error('Rating must be between 1 and 5.', 400);
}

// Confirm the product exists and is active.
$exists = db_guard(function () use ($pdo, $productId) {
    $stmt = $pdo->prepare('SELECT id FROM products WHERE id = :id AND is_active = 1 LIMIT 1');
    $stmt->execute([':id' => $productId]);
    return (bool) $stmt->fetch();
});
if (!$exists) {
    json_error('Product not found.', 404);
}

$reviewId = db_guard(function () use ($pdo, $productId, $user, $rating, $comment) {
    $stmt = $pdo->prepare(
        'INSERT INTO product_reviews (product_id, user_id, rating, comment, status)
         VALUES (:pid, :uid, :rating, :comment, "approved")'
    );
    $stmt->execute([
        ':pid'     => $productId,
        ':uid'     => (int) $user['id'],
        ':rating'  => $rating,
        ':comment' => $comment !== '' ? $comment : null,
    ]);
    return (int) $pdo->lastInsertId();
});

json_ok([
    'id'         => $reviewId,
    'product_id' => $productId,
    'rating'     => $rating,
    'comment'    => $comment !== '' ? $comment : null,
    'reviewer'   => $user['full_name'] ?: $user['username'],
], 'Review submitted.', 201);
