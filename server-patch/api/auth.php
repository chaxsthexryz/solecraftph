<?php
/**
 * Mobile Auth API (token based)
 * POST /api/auth.php?action=register  -> body: {username, email, password, full_name}
 * POST /api/auth.php?action=login     -> body: {username, password}
 * POST /api/auth.php?action=forgot    -> body: {email}  (emails a reset link)
 * GET  /api/auth.php?action=me        -> header: Authorization: Bearer <token>
 * POST /api/auth.php?action=logout    -> header: Authorization: Bearer <token>
 *
 * Issues opaque 64-char tokens stored in the existing `api_tokens` table. The
 * session-based web login (login.php / register.php / logout.php at the site
 * root) is untouched and keeps working exactly as before.
 */
require_once __DIR__ . '/../includes/auth.php';

/* ---------------------------------------------------------------------------
 * CORS + JSON headers. Same block as api/products.php.
 * ------------------------------------------------------------------------- */
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204); // preflight — no body
    exit;
}

/** How long a freshly issued token stays valid. */
const API_TOKEN_TTL_DAYS = 30;

/* ---------------------------------------------------------------------------
 * Helpers (local to this endpoint — includes/auth.php stays session-only apart
 * from the one shared bearer-token resolver it now exposes).
 * ------------------------------------------------------------------------- */

/** Decoded JSON request body, falling back to form-encoded POST. */
function auth_api_body(): array
{
    $json = json_decode(file_get_contents('php://input') ?: '', true);
    return is_array($json) ? $json : $_POST;
}

/** Sends {"error": "..."} with $status and stops. */
function auth_api_error(string $message, int $status): void
{
    http_response_code($status);
    echo json_encode(['error' => $message]);
    exit;
}

/**
 * Creates and stores a new token for $userId. Returns the raw token.
 * 64 hex chars, matching the api_tokens.token varchar(64) column.
 */
function auth_api_issue_token(int $userId): string
{
    $token   = bin2hex(random_bytes(32));
    $expires = (new DateTimeImmutable('+' . API_TOKEN_TTL_DAYS . ' days'))->format('Y-m-d H:i:s');

    $stmt = db()->prepare('INSERT INTO api_tokens (user_id, token, expires_at) VALUES (?, ?, ?)');
    $stmt->execute([$userId, $token, $expires]);

    // Cheap housekeeping so the table doesn't grow without bound.
    db()->prepare('DELETE FROM api_tokens WHERE expires_at < NOW()')->execute();

    return $token;
}

/** The public shape of a user, as returned by login / register / me. */
function auth_api_public_user(array $u): array
{
    return [
        'id'        => (int) $u['id'],
        'username'  => $u['username'],
        'full_name' => $u['full_name'],
        'email'     => $u['email'],
        'phone'     => $u['phone'],
        'address'   => $u['address'],
        'role'      => $u['role'],
        // Convenience flag for the app; saves it string-comparing `role`.
        'is_admin'  => ($u['role'] ?? '') === 'admin',
    ];
}

/** Loads the full user row for $userId, or null. */
function auth_api_find_user(int $userId): ?array
{
    $stmt = db()->prepare(
        'SELECT id, username, full_name, email, phone, address, role, status
           FROM users WHERE id = ? LIMIT 1'
    );
    $stmt->execute([$userId]);
    $row = $stmt->fetch();
    return $row ?: null;
}

$action = $_GET['action'] ?? '';
$method = $_SERVER['REQUEST_METHOD'];

/* ---------------------------------------------------------------------------
 * POST ?action=register
 * ------------------------------------------------------------------------- */
if ($action === 'register' && $method === 'POST') {
    $input = auth_api_body();

    $username = trim((string) ($input['username'] ?? ''));
    $email    = trim((string) ($input['email'] ?? ''));
    $password = (string) ($input['password'] ?? '');
    $fullName = trim((string) ($input['full_name'] ?? ''));

    if ($username === '' || $email === '' || $password === '') {
        auth_api_error('Username, email, and password are required.', 422);
    }
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        auth_api_error('Please enter a valid email address.', 422);
    }
    if (strlen($password) < 8) {
        auth_api_error('Password must be at least 8 characters.', 422);
    }

    // Reuses the web registration helper: uniqueness check + password_hash().
    [$ok, $message] = auth_register_customer($username, $email, $password);
    if (!$ok) {
        auth_api_error($message, 422);
    }

    $stmt = db()->prepare('SELECT id FROM users WHERE username = ? LIMIT 1');
    $stmt->execute([$username]);
    $userId = (int) $stmt->fetchColumn();

    // auth_register_customer() doesn't take a display name, so store it after.
    if ($fullName !== '') {
        $nameStmt = db()->prepare('UPDATE users SET full_name = ? WHERE id = ?');
        $nameStmt->execute([$fullName, $userId]);
    }

    // Log them straight in so the app doesn't need a second round trip.
    $token = auth_api_issue_token($userId);

    http_response_code(201);
    echo json_encode([
        'token' => $token,
        'user'  => auth_api_public_user(auth_api_find_user($userId)),
    ]);
    exit;
}

/* ---------------------------------------------------------------------------
 * POST ?action=login
 * ------------------------------------------------------------------------- */
if ($action === 'login' && $method === 'POST') {
    $input = auth_api_body();

    // `username` is the documented field; an email in the same box also works.
    $username = trim((string) ($input['username'] ?? $input['login'] ?? $input['email'] ?? ''));
    $password = (string) ($input['password'] ?? '');

    if ($username === '' || $password === '') {
        auth_api_error('Username and password are required.', 422);
    }

    $stmt = db()->prepare(
        'SELECT id, username, full_name, email, phone, address, password_hash, role, status
           FROM users WHERE username = ? OR email = ? LIMIT 1'
    );
    $stmt->execute([$username, $username]);
    $user = $stmt->fetch();

    // Same message for "no such user" and "wrong password" — don't leak which.
    if (!$user || !password_verify($password, $user['password_hash'])) {
        auth_api_error('Invalid username or password.', 401);
    }
    if (($user['status'] ?? 'active') === 'suspended') {
        auth_api_error('This account has been suspended.', 403);
    }

    $token = auth_api_issue_token((int) $user['id']);

    echo json_encode([
        'token' => $token,
        'user'  => auth_api_public_user($user),
    ]);
    exit;
}

/* ---------------------------------------------------------------------------
 * GET ?action=me
 * ------------------------------------------------------------------------- */
if ($action === 'me' && $method === 'GET') {
    $userId = auth_user_id_from_bearer_token();
    if ($userId === null) {
        auth_api_error('Valid Authorization Bearer token required.', 401);
    }

    $user = auth_api_find_user($userId);
    if (!$user || ($user['status'] ?? 'active') === 'suspended') {
        auth_api_error('Valid Authorization Bearer token required.', 401);
    }

    echo json_encode(['user' => auth_api_public_user($user)]);
    exit;
}

/* ---------------------------------------------------------------------------
 * POST ?action=logout — idempotent.
 * ------------------------------------------------------------------------- */
if ($action === 'logout' && $method === 'POST') {
    $token = auth_bearer_token_value();
    if ($token !== null) {
        $stmt = db()->prepare('DELETE FROM api_tokens WHERE token = ?');
        $stmt->execute([$token]);
    }

    echo json_encode(['message' => 'Logged out']);
    exit;
}

/* ---------------------------------------------------------------------------
 * POST ?action=forgot  -> body: {email}
 *
 * Emails a reset link. Answers identically whether or not the address has an
 * account — otherwise this endpoint becomes a way to enumerate your customers.
 * The link lands on the website; there is no in-app reset screen, because a
 * password reset should be reachable by someone who cannot get into the app.
 * ------------------------------------------------------------------------- */
if ($action === 'forgot' && $method === 'POST') {
    require_once __DIR__ . '/../includes/password_reset_service.php';

    $input = auth_api_body();
    $email = trim((string) ($input['email'] ?? ''));

    if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        auth_api_error('Please enter a valid email address.', 422);
    }

    password_reset_request($email);

    echo json_encode([
        'message' => 'If that email has an account, a reset link is on its way.',
    ]);
    exit;
}

http_response_code(400);
echo json_encode(['error' => 'Unknown or unsupported action. Use ?action=register, ?action=login, ?action=forgot, ?action=me, or ?action=logout']);
