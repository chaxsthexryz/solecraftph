<?php
require __DIR__ . '/bootstrap.php';
require_method('GET');

$rows = db_guard(function () use ($pdo) {
    $stmt = $pdo->query(
        'SELECT category,
                subcategory,
                COUNT(*) AS product_count
           FROM products
          WHERE is_active = 1
          GROUP BY category, subcategory
          ORDER BY category ASC, subcategory ASC'
    );
    return $stmt->fetchAll();
});

// Group subcategories under each category.
$grouped = [];
foreach ($rows as $r) {
    $cat = $r['category'];
    if (!isset($grouped[$cat])) {
        $grouped[$cat] = [
            'category'      => $cat,
            'product_count' => 0,
            'subcategories' => [],
        ];
    }
    $grouped[$cat]['product_count'] += (int) $r['product_count'];
    if ($r['subcategory'] !== null && $r['subcategory'] !== '') {
        $grouped[$cat]['subcategories'][] = [
            'name'          => $r['subcategory'],
            'product_count' => (int) $r['product_count'],
        ];
    }
}

json_ok(['categories' => array_values($grouped)], null, 200);
