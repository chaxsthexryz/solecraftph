<?php
require __DIR__ . '/bootstrap.php';
require_method('GET');

$banners = db_guard(function () use ($pdo) {
    $stmt = $pdo->query(
        'SELECT id, title, subtitle, link_url, sort_order
           FROM banners
          WHERE is_active = 1
          ORDER BY sort_order ASC, id ASC'
    );
    return $stmt->fetchAll();
});

$banners = array_map(static function (array $b): array {
    $b['id']         = (int) $b['id'];
    $b['sort_order'] = (int) $b['sort_order'];
    return $b;
}, $banners);

json_ok(['banners' => $banners], null, 200);
