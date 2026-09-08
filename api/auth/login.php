<?php
require __DIR__ . '/../bootstrap.php';
require_method('POST');

$in = body_input();

// Accept either "login" (username OR email) or explicit email/username.
$login    = input_str($in, 'login');
if ($login === '') {
    $login = input_str($in, 'email');
}
if ($login === '') {
    $login = input_str($in, 'username');
}
$password = (string) ($in['password'] ?? '');

if ($login === '' || $password === '') {
    json_error('Username/email and password are required.', 400);
}

$user = db_guard(function () use ($pdo, $login) {
    $stmt = $pdo->prepare(
        'SELECT id, username, full_name, email, phone, address, password_hash, role, status
           FROM users
          WHERE email = :login OR username = :login
          LIMIT 1'
    );
    $stmt->execute([':login' => $login]);
    return $stmt->fetch();
});

// Uniform error to avoid revealing which accounts exist.
if (!$user || !password_verify($password, $user['password_hash'])) {
    json_error('Invalid credentials.', 401);
}
if ($user['status'] !== 'active') {
    json_error('This account is suspended.', 403);
}

$tok = issue_token($pdo, (int) $user['id']);

unset($user['password_hash'], $user['status']);

json_ok([
    'user'       => $user,
    'token'      => $tok['token'],
    'expires_at' => $tok['expires_at'],
], 'Login successful.', 200);
