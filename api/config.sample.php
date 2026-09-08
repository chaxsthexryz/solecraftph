<?php
/**
 * SAMPLE ONLY — do NOT upload this file.
 *
 * Your live site already has  <site_root>/config/db.php  and the API reuses it.
 * The API's bootstrap.php expects that file to expose a connected PDO instance
 * in a variable named  $pdo  (it also auto-detects $conn / $db / $dbh).
 *
 * If your existing config/db.php already looks like the below, you do not need
 * to change anything. This is only here so you can confirm the shape.
 */

$DB_HOST = 'localhost';
$DB_NAME = 'your_database_name';
$DB_USER = 'your_db_user';
$DB_PASS = 'your_db_password';

try {
    $pdo = new PDO(
        "mysql:host={$DB_HOST};dbname={$DB_NAME};charset=utf8mb4",
        $DB_USER,
        $DB_PASS,
        [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]
    );
} catch (PDOException $e) {
    error_log('DB connection failed: ' . $e->getMessage());
    http_response_code(500);
    exit('Database connection error.');
}
