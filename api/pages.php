<?php
require __DIR__ . '/bootstrap.php';
require_method('GET');

$slug = trim((string) ($_GET['slug'] ?? ''));

if ($slug === '') {
    // No slug → list available pages (slug + title only).
    $pages = db_guard(function () use ($pdo) {
        $stmt = $pdo->query('SELECT slug, title, updated_at FROM cms_pages ORDER BY title ASC');
        return $stmt->fetchAll();
    });
    json_ok(['pages' => $pages], null, 200);
}

$page = db_guard(function () use ($pdo, $slug) {
    $stmt = $pdo->prepare('SELECT slug, title, content, updated_at FROM cms_pages WHERE slug = :slug LIMIT 1');
    $stmt->execute([':slug' => $slug]);
    return $stmt->fetch();
});

if (!$page) {
    json_error('Page not found.', 404);
}

json_ok($page, null, 200);
