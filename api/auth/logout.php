<?php
require __DIR__ . '/../bootstrap.php';
require_method('POST');

// Must present a valid token to know which row to delete.
require_auth($pdo);

$token = bearer_token();
db_guard(function () use ($pdo, $token) {
    $stmt = $pdo->prepare('DELETE FROM api_tokens WHERE token = :token');
    $stmt->execute([':token' => $token]);
});

json_ok(null, 'Logged out.', 200);
