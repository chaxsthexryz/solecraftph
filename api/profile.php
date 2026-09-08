<?php
require __DIR__ . '/bootstrap.php';
require_method('GET');

$user = require_auth($pdo);

// current_user() already excludes password_hash; expose a clean profile.
json_ok([
    'id'        => (int) $user['id'],
    'username'  => $user['username'],
    'full_name' => $user['full_name'],
    'email'     => $user['email'],
    'phone'     => $user['phone'],
    'address'   => $user['address'],
    'role'      => $user['role'],
], null, 200);
