<?php
require __DIR__ . '/bootstrap.php';
require_method('POST');

$in = body_input();

$name    = input_str($in, 'name');
$email   = strtolower(input_str($in, 'email'));
$subject = input_str($in, 'subject');
$message = input_str($in, 'message');

if ($name === '' || $email === '' || $subject === '' || $message === '') {
    json_error('Name, email, subject and message are all required.', 400);
}
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    json_error('Please provide a valid email address.', 400);
}
if (strlen($subject) > 200) {
    json_error('Subject is too long.', 400);
}

$id = db_guard(function () use ($pdo, $name, $email, $subject, $message) {
    $stmt = $pdo->prepare(
        'INSERT INTO contact_messages (name, email, subject, message, status)
         VALUES (:name, :email, :subject, :message, "new")'
    );
    $stmt->execute([
        ':name'    => $name,
        ':email'   => $email,
        ':subject' => $subject,
        ':message' => $message,
    ]);
    return (int) $pdo->lastInsertId();
});

json_ok(['id' => $id], 'Your message has been sent.', 201);
