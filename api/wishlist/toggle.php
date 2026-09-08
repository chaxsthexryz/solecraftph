<?php
require __DIR__ . '/../bootstrap.php';
require_method('POST');

$user = require_auth($pdo);
$in   = body_input();

$productId = (int) ($in['product_id'] ?? 0);
if ($productId <= 0) {
    json_error('A valid product_id is required.', 400);
}

// Product must exist and be active.
$exists = db_guard(function () use ($pdo, $productId) {
    $stmt = $pdo->prepare('SELECT id FROM products WHERE id = :id AND is_active = 1 LIMIT 1');
    $stmt->execute([':id' => $productId]);
    return (bool) $stmt->fetch();
});
if (!$exists) {
    json_error('Product not found.', 404);
}

$inWishlist = db_guard(function () use ($pdo, $user, $productId) {
    $find = $pdo->prepare('SELECT id FROM wishlists WHERE user_id = :uid AND product_id = :pid LIMIT 1');
    $find->execute([':uid' => (int) $user['id'], ':pid' => $productId]);
    $existing = $find->fetch();

    if ($existing) {
        $del = $pdo->prepare('DELETE FROM wishlists WHERE id = :id');
        $del->execute([':id' => (int) $existing['id']]);
        return false;   // now removed
    }

    // INSERT IGNORE guards the unique(user_id, product_id) constraint on races.
    $ins = $pdo->prepare('INSERT IGNORE INTO wishlists (user_id, product_id) VALUES (:uid, :pid)');
    $ins->execute([':uid' => (int) $user['id'], ':pid' => $productId]);
    return true;        // now added
}) ;

json_ok([
    'product_id'   => $productId,
    'in_wishlist'  => $inWishlist,
], $inWishlist ? 'Added to wishlist.' : 'Removed from wishlist.', 200);
