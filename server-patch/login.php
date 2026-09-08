<?php
require_once __DIR__ . '/config/app.php';
require_once __DIR__ . '/includes/auth.php';

if (auth_is_logged_in()) {
    header('Location: ' . BASE_PATH . '/index.php');
    exit;
}

$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = trim($_POST['username'] ?? '');
    $password = $_POST['password'] ?? '';

    if (auth_attempt_login($username, $password)) {
        $redirect = $_POST['redirect'] ?? (BASE_PATH . '/index.php');
        header('Location: ' . $redirect);
        exit;
    }
    $error = 'Invalid username or password.';
}

$redirectTo = $_GET['redirect'] ?? (BASE_PATH . '/index.php');
$pageTitle  = 'Log In — SoleCraftPH';
require __DIR__ . '/includes/header.php';
?>

<section class="section">
  <div class="wrap" style="max-width:440px;">
    <h1 class="display" style="margin-bottom:24px;">Log In</h1>
    <div class="panel">
      <?php if ($error): ?><div class="alert alert--error"><?= htmlspecialchars($error) ?></div><?php endif; ?>
      <form method="post" action="<?= BASE_PATH ?>/login.php">
        <input type="hidden" name="redirect" value="<?= htmlspecialchars($redirectTo) ?>">
        <div class="form-field">
          <label>Username or Email</label>
          <input type="text" name="username" required autofocus>
        </div>
        <div class="form-field">
          <label>Password</label>
          <input type="password" name="password" required>
        </div>
        <button type="submit" class="btn btn--solid" style="width:100%;justify-content:center;">Log In</button>
      </form>
      <p style="margin-top:14px;font-size:14px;">
        <a href="<?= BASE_PATH ?>/forgot-password.php">Forgot your password?</a>
      </p>
      <p class="mono" style="margin-top:18px;color:var(--gray);">
        New here? <a href="<?= BASE_PATH ?>/register.php">Create an account</a>
      </p>
    </div>
  </div>
</section>

<?php require __DIR__ . '/includes/footer.php'; ?>