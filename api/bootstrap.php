<?php
/**
 * SoleCraftPH REST API — shared bootstrap.
 *
 * Included by EVERY endpoint. Handles:
 *   - CORS (incl. OPTIONS preflight)
 *   - JSON response envelope helpers
 *   - JSON request-body parsing
 *   - Bearer-token authentication against `api_tokens`
 *   - A single PDO handle ($pdo) reused from the site's existing config/db.php
 *
 * It NEVER creates/drops tables and never leaks raw SQL errors to clients.
 */

declare(strict_types=1);

// ---------------------------------------------------------------------------
// Error handling — log everything, expose nothing.
// ---------------------------------------------------------------------------
error_reporting(E_ALL);
ini_set('display_errors', '0');          // never echo PHP/SQL errors to the client
ini_set('log_errors', '1');

// ---------------------------------------------------------------------------
// CORS — applied to every request.
// ---------------------------------------------------------------------------
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type');
header('Access-Control-Max-Age: 86400');
header('Content-Type: application/json; charset=utf-8');

// Preflight — answer and stop.
if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

// ---------------------------------------------------------------------------
// JSON helpers.
// ---------------------------------------------------------------------------

/**
 * Emit the standard envelope and terminate.
 */
function json_response(bool $success, $data = null, ?string $message = null, int $code = 200): void
{
    http_response_code($code);
    echo json_encode([
        'success' => $success,
        'data'    => $data,
        'message' => $message,
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function json_ok($data = null, ?string $message = null, int $code = 200): void
{
    json_response(true, $data, $message, $code);
}

function json_error(string $message, int $code = 400, $data = null): void
{
    json_response(false, $data, $message, $code);
}

/**
 * Only allow the given HTTP method(s); otherwise 405.
 */
function require_method(string ...$methods): void
{
    $m = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if (!in_array($m, $methods, true)) {
        json_error('Method not allowed.', 405);
    }
}

/**
 * Parse the JSON request body into an associative array.
 * Falls back to form-encoded POST data when the body is not JSON.
 */
function body_input(): array
{
    $raw = file_get_contents('php://input');
    if ($raw !== false && $raw !== '') {
        $decoded = json_decode($raw, true);
        if (is_array($decoded)) {
            return $decoded;
        }
    }
    return $_POST ?? [];
}

/**
 * Read a trimmed string value from an input array.
 */
function input_str(array $src, string $key, string $default = ''): string
{
    return isset($src[$key]) ? trim((string) $src[$key]) : $default;
}

// ---------------------------------------------------------------------------
// Database — reuse the site's existing PDO connection.
// ---------------------------------------------------------------------------
$__dbFile = __DIR__ . '/../config/db.php';   // site_root/config/db.php
if (!is_file($__dbFile)) {
    error_log('SoleCraftPH API: config/db.php not found at ' . $__dbFile);
    json_error('Server configuration error.', 500);
}
require $__dbFile;

// Normalise to $pdo regardless of what the existing file named the handle.
if (!isset($pdo) || !($pdo instanceof PDO)) {
    if (isset($conn) && $conn instanceof PDO) {
        $pdo = $conn;
    } elseif (isset($db) && $db instanceof PDO) {
        $pdo = $db;
    } elseif (isset($dbh) && $dbh instanceof PDO) {
        $pdo = $dbh;
    }
}

if (!isset($pdo) || !($pdo instanceof PDO)) {
    error_log('SoleCraftPH API: no PDO instance exposed by config/db.php');
    json_error('Server configuration error.', 500);
}

// Make PDO throw and fetch associative by default (harmless if already set).
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);

/**
 * Centralised guard: run a DB closure, translate any PDOException into a
 * clean 500 without leaking SQL. Usage: db_guard(fn() => ...).
 */
function db_guard(callable $fn)
{
    try {
        return $fn();
    } catch (PDOException $e) {
        error_log('SoleCraftPH API DB error: ' . $e->getMessage());
        json_error('A database error occurred.', 500);
    }
}

// ---------------------------------------------------------------------------
// Authentication.
// ---------------------------------------------------------------------------

/**
 * Extract the raw bearer token from the Authorization header.
 * Works around shared hosts that strip the header (falls back to
 * REDIRECT_HTTP_AUTHORIZATION; see api/.htaccess).
 */
function bearer_token(): ?string
{
    $header = '';
    if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
        $header = $_SERVER['HTTP_AUTHORIZATION'];
    } elseif (isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
        $header = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
    } elseif (function_exists('getallheaders')) {
        foreach (getallheaders() as $k => $v) {
            if (strcasecmp($k, 'Authorization') === 0) {
                $header = $v;
                break;
            }
        }
    }
    if (preg_match('/Bearer\s+(\S+)/i', $header, $m)) {
        return $m[1];
    }
    return null;
}

/**
 * Resolve the current user from the bearer token, or null if unauthenticated.
 * Returns the full user row (minus password_hash) on success.
 */
function current_user(PDO $pdo): ?array
{
    $token = bearer_token();
    if ($token === null || $token === '') {
        return null;
    }
    return db_guard(function () use ($pdo, $token) {
        $stmt = $pdo->prepare(
            'SELECT u.id, u.username, u.full_name, u.email, u.phone, u.address,
                    u.role, u.status
               FROM api_tokens t
               JOIN users u ON u.id = t.user_id
              WHERE t.token = :token
                AND t.expires_at > NOW()
              LIMIT 1'
        );
        $stmt->execute([':token' => $token]);
        $row = $stmt->fetch();
        if (!$row) {
            return null;
        }
        if (($row['status'] ?? 'active') !== 'active') {
            return null;   // suspended accounts cannot use the API
        }
        return $row;
    });
}

/**
 * Require a valid token; emits 401 and stops if missing/invalid.
 * Returns the authenticated user row.
 */
function require_auth(PDO $pdo): array
{
    $user = current_user($pdo);
    if ($user === null) {
        json_error('Authentication required.', 401);
    }
    return $user;
}

/**
 * Turn a stored image path into an absolute URL so mobile/native clients can
 * load it directly. Leaves already-absolute URLs untouched.
 */
function absolute_image(?string $path): ?string
{
    if ($path === null || $path === '') {
        return null;
    }
    if (preg_match('#^https?://#i', $path)) {
        return $path;
    }
    return 'https://snow-jellyfish-553645.hostingersite.com/' . ltrim($path, '/');
}

/**
 * Issue a fresh 64-char token for a user with 30-day expiry.
 */
function issue_token(PDO $pdo, int $userId): array
{
    $token = bin2hex(random_bytes(32));                 // 64 hex chars
    $expires = (new DateTimeImmutable('+30 days'))->format('Y-m-d H:i:s');
    db_guard(function () use ($pdo, $userId, $token, $expires) {
        $stmt = $pdo->prepare(
            'INSERT INTO api_tokens (user_id, token, expires_at)
             VALUES (:uid, :token, :exp)'
        );
        $stmt->execute([':uid' => $userId, ':token' => $token, ':exp' => $expires]);
    });
    return ['token' => $token, 'expires_at' => $expires];
}
