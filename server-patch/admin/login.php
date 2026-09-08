<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/login_throttle.php';

if (auth_is_admin()) {
    header('Location: dashboard.php');
    exit;
}

$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = trim($_POST['username'] ?? '');
    $password = $_POST['password'] ?? '';

    // Refused before the password is even looked at, so a throttled attempt
    // cannot be used to probe whether an account exists.
    $wait = login_throttle_delay($username);
    if ($wait > 0) {
        $error = login_throttle_message($wait);
    } else {
        $ok = auth_attempt_login($username, $password) && auth_is_admin();
        login_attempt_record($username, $ok);
        if ($ok) {
            header('Location: dashboard.php');
            exit;
        }
        $error = 'Invalid username or password, or account is not an admin.';
    }
}

$pageTitle = 'Admin Login — SoleCraftPH';
require __DIR__ . '/../includes/header.php';
?>

<section class="section">
  <div class="wrap" style="max-width:440px;">
    <h1 class="display" style="margin-bottom:24px;">Admin Login</h1>
    <div class="panel">
      <?php if ($error): ?><div class="alert alert--error"><?= htmlspecialchars($error) ?></div><?php endif; ?>
      <form method="post" action="login.php">
        <div class="form-field"><label>Username</label><input type="text" name="username" required autofocus></div>
        <div class="form-field"><label>Password</label><input type="password" name="password" required></div>
        <button type="submit" class="btn btn--solid" style="width:100%;justify-content:center;">Log In</button>
      </form>
      <p class="mono" style="margin-top:18px;color:var(--gray);">Default: admin / Admin@123</p>
    </div>
  </div>
</section>

<?php require __DIR__ . '/../includes/footer.php'; ?>
