<?php
require __DIR__ . '/../bootstrap.php';
require_method('POST');

$user = require_auth($pdo);
$in   = body_input();
$uid  = (int) $user['id'];

// Collect only the fields that were supplied.
$fields = [];
$params = [':id' => $uid];

if (array_key_exists('full_name', $in)) {
    $fields[':full_name'] = 'full_name = :full_name';
    $params[':full_name'] = input_str($in, 'full_name') ?: null;
}
if (array_key_exists('phone', $in)) {
    $fields[':phone'] = 'phone = :phone';
    $params[':phone'] = input_str($in, 'phone') ?: null;
}
if (array_key_exists('address', $in)) {
    $fields[':address'] = 'address = :address';
    $params[':address'] = input_str($in, 'address') ?: null;
}
if (array_key_exists('email', $in)) {
    $email = strtolower(input_str($in, 'email'));
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        json_error('Please provide a valid email address.', 400);
    }
    $fields[':email'] = 'email = :email';
    $params[':email'] = $email;
}

// Optional password change.
if (!empty($in['new_password'])) {
    $newPass = (string) $in['new_password'];
    $current = (string) ($in['current_password'] ?? '');
    if (strlen($newPass) < 6) {
        json_error('New password must be at least 6 characters.', 400);
    }
    // Verify current password before changing.
    $row = db_guard(function () use ($pdo, $uid) {
        $stmt = $pdo->prepare('SELECT password_hash FROM users WHERE id = :id LIMIT 1');
        $stmt->execute([':id' => $uid]);
        return $stmt->fetch();
    });
    if (!$row || !password_verify($current, $row['password_hash'])) {
        json_error('Current password is incorrect.', 400);
    }
    $fields[':password_hash'] = 'password_hash = :password_hash';
    $params[':password_hash'] = password_hash($newPass, PASSWORD_DEFAULT);
}

if (count($fields) === 0) {
    json_error('No fields to update.', 400);
}

db_guard(function () use ($pdo, $fields, $params, $in, $uid) {
    // Friendly duplicate-email check.
    if (isset($params[':email'])) {
        $chk = $pdo->prepare('SELECT id FROM users WHERE email = :email AND id <> :id LIMIT 1');
        $chk->execute([':email' => $params[':email'], ':id' => $uid]);
        if ($chk->fetch()) {
            json_error('That email is already in use.', 409);
        }
    }
    $sql = 'UPDATE users SET ' . implode(', ', array_values($fields)) . ' WHERE id = :id';
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
});

// Return the fresh profile.
$fresh = db_guard(function () use ($pdo, $uid) {
    $stmt = $pdo->prepare(
        'SELECT id, username, full_name, email, phone, address, role
           FROM users WHERE id = :id LIMIT 1'
    );
    $stmt->execute([':id' => $uid]);
    return $stmt->fetch();
});
$fresh['id'] = (int) $fresh['id'];

json_ok($fresh, 'Profile updated.', 200);
