<?php
require __DIR__ . '/bootstrap.php';
require_method('GET');

// Lightweight, public API directory — handy for verifying the deployment.
json_ok([
    'name'    => 'SoleCraftPH API',
    'version' => '1.0',
    'endpoints' => [
        'POST /api/auth/register.php',
        'POST /api/auth/login.php',
        'POST /api/auth/logout.php            (auth)',
        'GET  /api/products.php',
        'GET  /api/products/detail.php?id=',
        'GET  /api/products/reviews.php?product_id=',
        'POST /api/products/review.php        (auth)',
        'GET  /api/categories.php',
        'GET  /api/banners.php',
        'GET  /api/pages.php?slug=',
        'POST /api/checkout.php',
        'GET  /api/orders.php                 (auth)',
        'GET  /api/orders/detail.php?id=      (auth)',
        'GET  /api/wishlist.php               (auth)',
        'POST /api/wishlist/toggle.php        (auth)',
        'GET  /api/profile.php                (auth)',
        'POST /api/profile/update.php         (auth)',
        'POST /api/contact.php',
    ],
], 'SoleCraftPH API is running.', 200);
