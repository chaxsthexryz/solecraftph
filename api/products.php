<?php
require __DIR__ . '/bootstrap.php';
require_method('GET');

// --- Filters -------------------------------------------------------------
$category    = trim((string) ($_GET['category'] ?? ''));
$subcategory = trim((string) ($_GET['subcategory'] ?? ''));
$search      = trim((string) ($_GET['search'] ?? ''));
$sort        = trim((string) ($_GET['sort'] ?? 'newest'));
$page        = max(1, (int) ($_GET['page'] ?? 1));
$perPage     = (int) ($_GET['per_page'] ?? 12);
$perPage     = max(1, min($perPage, 50));      // clamp
$offset      = ($page - 1) * $perPage;

$where  = ['is_active = 1'];
$params = [];

if ($category !== '') {
    $where[] = 'category = :category';
    $params[':category'] = $category;
}
if ($subcategory !== '') {
    $where[] = 'subcategory = :subcategory';
    $params[':subcategory'] = $subcategory;
}
if ($search !== '') {
    // LIKE keeps it simple and works even without FULLTEXT tuning.
    $where[] = '(name LIKE :search OR description LIKE :search
                 OR category LIKE :search OR subcategory LIKE :search)';
    $params[':search'] = '%' . $search . '%';
}

// --- Sort (whitelisted) --------------------------------------------------
$orderMap = [
    'newest'      => 'created_at DESC',
    'oldest'      => 'created_at ASC',
    'price_asc'   => 'COALESCE(sale_price, price) ASC',
    'price_desc'  => 'COALESCE(sale_price, price) DESC',
    'name_asc'    => 'name ASC',
    'name_desc'   => 'name DESC',
];
$orderBy = $orderMap[$sort] ?? $orderMap['newest'];

$whereSql = implode(' AND ', $where);

$result = db_guard(function () use ($pdo, $whereSql, $params, $orderBy, $perPage, $offset) {
    // Total count for pagination.
    $countStmt = $pdo->prepare("SELECT COUNT(*) FROM products WHERE $whereSql");
    $countStmt->execute($params);
    $total = (int) $countStmt->fetchColumn();

    $sql = "SELECT id, name, category, subcategory, description, price, sale_price,
                   stock, low_stock_threshold, badge, image, created_at
              FROM products
             WHERE $whereSql
             ORDER BY $orderBy
             LIMIT :limit OFFSET :offset";
    $stmt = $pdo->prepare($sql);
    foreach ($params as $k => $v) {
        $stmt->bindValue($k, $v);
    }
    $stmt->bindValue(':limit', $perPage, PDO::PARAM_INT);
    $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
    $stmt->execute();
    return ['rows' => $stmt->fetchAll(), 'total' => $total];
});

// Normalise numeric/boolean types for the client.
$products = array_map(static function (array $p): array {
    $p['id']                  = (int) $p['id'];
    $p['price']               = (float) $p['price'];
    $p['sale_price']          = $p['sale_price'] !== null ? (float) $p['sale_price'] : null;
    $p['stock']               = (int) $p['stock'];
    $p['low_stock_threshold'] = (int) $p['low_stock_threshold'];
    $p['on_sale']             = $p['sale_price'] !== null;
    $p['image']               = absolute_image($p['image']);
    return $p;
}, $result['rows']);

$total = $result['total'];

json_ok([
    'products'   => $products,
    'pagination' => [
        'page'        => $page,
        'per_page'    => $perPage,
        'total'       => $total,
        'total_pages' => (int) ceil($total / $perPage),
    ],
], null, 200);
