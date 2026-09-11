<?php
/**
 * Returns / Refunds Service.
 */
require_once __DIR__ . '/../config/db.php';

function return_create(int $orderId, ?int $userId, string $reason, string $details): int
{
    $stmt = db()->prepare(
        'INSERT INTO returns (order_id, user_id, reason, details, status) VALUES (?, ?, ?, ?, "requested")'
    );
    $stmt->execute([$orderId, $userId, $reason, $details]);
    return (int) db()->lastInsertId();
}

function return_list_for_user(int $userId): array
{
    $stmt = db()->prepare(
        'SELECT r.*, o.total_amount FROM returns r JOIN orders o ON o.id = r.order_id
         WHERE r.user_id = ? ORDER BY r.created_at DESC'
    );
    $stmt->execute([$userId]);
    return $stmt->fetchAll();
}

function return_list_all(int $limit = 300): array
{
    $stmt = db()->prepare(
        'SELECT r.*, o.customer_name, o.customer_email, o.total_amount FROM returns r
         JOIN orders o ON o.id = r.order_id
         ORDER BY r.created_at DESC LIMIT ?'
    );
    $stmt->bindValue(1, $limit, PDO::PARAM_INT);
    $stmt->execute();
    return $stmt->fetchAll();
}

function return_find(int $id): ?array
{
    $stmt = db()->prepare(
        'SELECT r.*, o.customer_name, o.customer_email, o.total_amount FROM returns r
         JOIN orders o ON o.id = r.order_id WHERE r.id = ? LIMIT 1'
    );
    $stmt->execute([$id]);
    $row = $stmt->fetch();
    return $row ?: null;
}

function return_update_status(int $id, string $status, string $adminNotes = ''): void
{
    if (!in_array($status, ['requested', 'approved', 'rejected', 'refunded'], true)) {
        return;
    }
    $stmt = db()->prepare('UPDATE returns SET status = ?, admin_notes = ? WHERE id = ?');
    $stmt->execute([$status, $adminNotes, $id]);
}

function return_has_existing(int $orderId): bool
{
    $stmt = db()->prepare('SELECT 1 FROM returns WHERE order_id = ? LIMIT 1');
    $stmt->execute([$orderId]);
    return (bool) $stmt->fetchColumn();
}
