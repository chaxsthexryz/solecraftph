<?php
/**
 * Authentication (Basic) - session based, bcrypt password hashing.
 */
require_once __DIR__ . '/../config/db.php';

require_once __DIR__ . '/session.php';

function auth_attempt_login(string $username, string $password): bool
{
    $stmt = db()->prepare('SELECT id, username, password_hash, role, status FROM users WHERE username = ? OR email = ? LIMIT 1');
    $stmt->execute([$username, $username]);
    $user = $stmt->fetch();

    if ($user && ($user['status'] ?? 'active') === 'suspended') {
        return false;
    }

    if ($user && password_verify($password, $user['password_hash'])) {
        session_regenerate_id(true);
        $_SESSION['user_id']  = $user['id'];
        $_SESSION['username'] = $user['username'];
        $_SESSION['role']     = $user['role'];
        // Whatever they put in the bag while logged out follows them into the
        // account cart, so signing in never silently empties the cart.
        require_once __DIR__ . '/cart.php';
        cart_merge_session_into_account((int) $user['id']);
        return true;
    }
    return false;
}

function auth_logout(): void
{
    $_SESSION = [];
    session_destroy();
}

function auth_is_logged_in(): bool
{
    return isset($_SESSION['user_id']);
}

function auth_is_admin(): bool
{
    return auth_is_logged_in() && ($_SESSION['role'] ?? '') === 'admin';
}

function auth_require_admin(): void
{
    if (!auth_is_admin()) {
        header('Location: login.php');
        exit;
    }
}

function auth_register_customer(string $username, string $email, string $password): array
{
    $db = db();

    $check = $db->prepare('SELECT id FROM users WHERE username = ? OR email = ? LIMIT 1');
    $check->execute([$username, $email]);
    if ($check->fetch()) {
        return [false, 'Username or email is already registered.'];
    }

    $hash = password_hash($password, PASSWORD_DEFAULT);
    $stmt = $db->prepare('INSERT INTO users (username, email, password_hash, role) VALUES (?, ?, ?, "customer")');
    $stmt->execute([$username, $email, $hash]);

    return [true, 'Account created successfully.'];
}

/** Redirects to the login page (preserving where the user was headed) unless already logged in. */
function auth_require_login(): void
{
    if (!auth_is_logged_in()) {
        $base = defined('BASE_PATH') ? BASE_PATH : '';
        $redirect = $base . $_SERVER['REQUEST_URI'];
        header('Location: ' . $base . '/login.php?redirect=' . urlencode($redirect));
        exit;
    }
}

/** A logged-in user's own record is blocked from checking their own status (suspension is enforced at login) */
function auth_current_user(): ?array
{
    if (!auth_is_logged_in()) {
        return null;
    }
    $stmt = db()->prepare('SELECT id, username, full_name, email, phone, address, role, status, created_at FROM users WHERE id = ? LIMIT 1');
    $stmt->execute([$_SESSION['user_id']]);
    $row = $stmt->fetch();
    return $row ?: null;
}

function auth_update_profile(int $userId, array $data): void
{
    $stmt = db()->prepare('UPDATE users SET full_name = ?, phone = ?, address = ? WHERE id = ?');
    $stmt->execute([$data['full_name'] ?? null, $data['phone'] ?? null, $data['address'] ?? null, $userId]);
}

function auth_change_password(int $userId, string $newPassword): void
{
    $hash = password_hash($newPassword, PASSWORD_DEFAULT);
    $stmt = db()->prepare('UPDATE users SET password_hash = ? WHERE id = ?');
    $stmt->execute([$hash, $userId]);
}

function auth_verify_password(int $userId, string $password): bool
{
    $stmt = db()->prepare('SELECT password_hash FROM users WHERE id = ? LIMIT 1');
    $stmt->execute([$userId]);
    $hash = $stmt->fetchColumn();
    return $hash && password_verify($password, $hash);
}

/** Admin: list customer accounts */
function user_list_customers(int $limit = 500): array
{
    $stmt = db()->prepare("SELECT * FROM users WHERE role = 'customer' ORDER BY created_at DESC LIMIT ?");
    $stmt->bindValue(1, $limit, PDO::PARAM_INT);
    $stmt->execute();
    return $stmt->fetchAll();
}

/** Admin: list admin accounts */
function user_list_admins(int $limit = 200): array
{
    $stmt = db()->prepare("SELECT * FROM users WHERE role = 'admin' ORDER BY created_at DESC LIMIT ?");
    $stmt->bindValue(1, $limit, PDO::PARAM_INT);
    $stmt->execute();
    return $stmt->fetchAll();
}

function user_find(int $id): ?array
{
    $stmt = db()->prepare('SELECT * FROM users WHERE id = ? LIMIT 1');
    $stmt->execute([$id]);
    $row = $stmt->fetch();
    return $row ?: null;
}

function user_set_status(int $id, string $status): void
{
    if (!in_array($status, ['active', 'suspended'], true)) {
        return;
    }
    $stmt = db()->prepare('UPDATE users SET status = ? WHERE id = ?');
    $stmt->execute([$status, $id]);
}

/** Admin: create another admin account */
function user_create_admin(string $username, string $email, string $password): array
{
    $db = db();
    $check = $db->prepare('SELECT id FROM users WHERE username = ? OR email = ? LIMIT 1');
    $check->execute([$username, $email]);
    if ($check->fetch()) {
        return [false, 'Username or email is already registered.'];
    }
    $hash = password_hash($password, PASSWORD_DEFAULT);
    $stmt = $db->prepare('INSERT INTO users (username, email, password_hash, role) VALUES (?, ?, ?, "admin")');
    $stmt->execute([$username, $email, $hash]);
    return [true, 'Admin account created.'];
}

function user_delete(int $id): void
{
    $stmt = db()->prepare('DELETE FROM users WHERE id = ?');
    $stmt->execute([$id]);
}

/* ---------------------------------------------------------------------------
 * Mobile app: bearer-token auth (additive — nothing above this line changed).
 *
 * The website keeps using PHP sessions. api/auth.php issues opaque tokens into
 * the existing `api_tokens` table, and these two helpers read them back so any
 * api/*.php endpoint can identify a mobile caller.
 * ------------------------------------------------------------------------- */

/**
 * Extracts the raw token from the Authorization header.
 *
 * Apache/CGI on shared hosting (Hostinger included) sometimes drops the
 * Authorization header before PHP sees it, so this checks the CGI-rewritten
 * variant and getallheaders() as fallbacks.
 */
function auth_bearer_token_value(): ?string
{
    $header = $_SERVER['HTTP_AUTHORIZATION']
        ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');

    if ($header === '' && function_exists('getallheaders')) {
        foreach (getallheaders() as $key => $value) {
            if (strcasecmp($key, 'Authorization') === 0) {
                $header = (string) $value;
                break;
            }
        }
    }

    if (!preg_match('/Bearer\s+(\S+)/i', (string) $header, $m)) {
        return null;
    }
    return $m[1];
}

/** Resolves a Bearer token from the Authorization header to a user_id, or null. */
function auth_user_id_from_bearer_token(): ?int
{
    $token = auth_bearer_token_value();
    if ($token === null) {
        return null;
    }

    $stmt = db()->prepare('SELECT user_id FROM api_tokens WHERE token = ? AND expires_at > NOW() LIMIT 1');
    $stmt->execute([$token]);
    $userId = $stmt->fetchColumn();

    return $userId ? (int) $userId : null;
}