<?php
require __DIR__ . '/../bootstrap.php';
require_method('POST');

$in = body_input();

$username = input_str($in, 'username');
$email    = strtolower(input_str($in, 'email'));
$password = (string) ($in['password'] ?? '');
$fullName = input_str($in, 'full_name');
$phone    = input_str($in, 'phone');
$address  = input_str($in, 'address');

// --- Validation ---------------------------------------------------------
if ($username === '' || $email === '' || $password === '') {
    json_error('Username, email and password are required.', 400);
}
if (strlen($username) > 60) {
    json_error('Username is too long.', 400);
}
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    json_error('Please provide a valid email address.', 400);
}
if (strlen($password) < 6) {
    json_error('Password must be at least 6 characters.', 400);
}

$hash = password_hash($password, PASSWORD_DEFAULT);

$user = db_guard(function () use ($pdo, $username, $email, $fullName, $phone, $address, $hash) {
    // Pre-check for friendly duplicate messages (unique constraints still guard).
    $check = $pdo->prepare('SELECT username, email FROM users WHERE username = :u OR email = :e LIMIT 1');
    $check->execute([':u' => $username, ':e' => $email]);
    if ($row = $check->fetch()) {
        if (strcasecmp($row['email'], $email) === 0) {
            json_error('An account with that email already exists.', 409);
        }
        json_error('That username is already taken.', 409);
    }

    $stmt = $pdo->prepare(
        'INSERT INTO users (username, full_name, email, phone, address, password_hash, role, status)
         VALUES (:username, :full_name, :email, :phone, :address, :hash, "customer", "active")'
    );
    $stmt->execute([
        ':username'  => $username,
        ':full_name' => $fullName !== '' ? $fullName : null,
        ':email'     => $email,
        ':phone'     => $phone !== '' ? $phone : null,
        ':address'   => $address !== '' ? $address : null,
        ':hash'      => $hash,
    ]);
    $id = (int) $pdo->lastInsertId();

    return [
        'id'        => $id,
        'username'  => $username,
        'full_name' => $fullName !== '' ? $fullName : null,
        'email'     => $email,
        'phone'     => $phone !== '' ? $phone : null,
        'address'   => $address !== '' ? $address : null,
        'role'      => 'customer',
    ];
});

$tok = issue_token($pdo, (int) $user['id']);

json_ok([
    'user'       => $user,
    'token'      => $tok['token'],
    'expires_at' => $tok['expires_at'],
], 'Registration successful.', 201);
