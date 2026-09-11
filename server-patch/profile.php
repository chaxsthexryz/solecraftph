<?php
require_once __DIR__ . '/config/app.php';
require_once __DIR__ . '/includes/auth.php';
auth_require_login();

$userId = (int) $_SESSION['user_id'];
$error = '';
$success = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $formAction = $_POST['form_action'] ?? '';

    if ($formAction === 'profile') {
        auth_update_profile($userId, [
            'full_name' => trim($_POST['full_name'] ?? ''),
            'phone'     => trim($_POST['phone'] ?? ''),
            'address'   => trim($_POST['address'] ?? ''),
        ]);
        $success = 'Your profile has been updated.';
    } elseif ($formAction === 'password') {
        $current = $_POST['current_password'] ?? '';
        $new     = $_POST['new_password'] ?? '';
        $confirm = $_POST['confirm_password'] ?? '';

        if (!auth_verify_password($userId, $current)) {
            $error = 'Your current password is incorrect.';
        } elseif (strlen($new) < 8) {
            $error = 'New password must be at least 8 characters long.';
        } elseif ($new !== $confirm) {
            $error = 'New passwords do not match.';
        } else {
            auth_change_password($userId, $new);
            $success = 'Your password has been changed.';
        }
    }
}

$me = auth_current_user();

$pageTitle = 'My Profile — SoleCraftPH';
require __DIR__ . '/includes/header.php';
?>

<header class="pagehead">
  <div class="wrap">
    <h1 class="display">My Account</h1>
    <p>Welcome back, <?= htmlspecialchars($me['full_name'] ?: $me['username']) ?>.</p>
  </div>
</header>
<div class="wrap" style="margin-top:18px;">
  <a href="<?= BASE_PATH ?>/addresses.php" class="btn">Delivery addresses &rarr;</a>
</div>

<section class="section" style="padding-top:0;">
  <div class="wrap">
    <nav class="subnav">
      <a href="<?= BASE_PATH ?>/profile.php" class="active">Profile</a>
      <a href="<?= BASE_PATH ?>/orders.php">Order History</a>
      <a href="<?= BASE_PATH ?>/wishlist.php">Wishlist</a>
      <a href="<?= BASE_PATH ?>/notifications.php">Notifications</a>
    </nav>

    <?php if ($error): ?><div class="alert alert--error"><?= htmlspecialchars($error) ?></div><?php endif; ?>
    <?php if ($success): ?><div class="alert alert--success"><?= htmlspecialchars($success) ?></div><?php endif; ?>

    <div class="form-grid">
      <div class="panel">
        <h3 class="display" style="font-size:24px;margin-bottom:18px;">Personal Information</h3>
        <form method="post" action="<?= BASE_PATH ?>/profile.php">
          <input type="hidden" name="form_action" value="profile">
          <div class="form-field">
            <label>Username</label>
            <input type="text" value="<?= htmlspecialchars($me['username']) ?>" disabled>
          </div>
          <div class="form-field">
            <label>Email</label>
            <input type="text" value="<?= htmlspecialchars($me['email']) ?>" disabled>
          </div>
          <div class="form-field">
            <label>Full Name</label>
            <input type="text" name="full_name" value="<?= htmlspecialchars($me['full_name'] ?? '') ?>">
          </div>
          <div class="form-field">
            <label>Phone</label>
            <input type="text" name="phone" value="<?= htmlspecialchars($me['phone'] ?? '') ?>">
          </div>
          <div class="form-field">
            <label>Shipping Address</label>
            <textarea name="address"><?= htmlspecialchars($me['address'] ?? '') ?></textarea>
          </div>
          <button type="submit" class="btn btn--solid">Save Changes</button>
        </form>
      </div>

      <div class="panel">
        <h3 class="display" style="font-size:24px;margin-bottom:18px;">Change Password</h3>
        <form method="post" action="<?= BASE_PATH ?>/profile.php">
          <input type="hidden" name="form_action" value="password">
          <div class="form-field">
            <label>Current Password</label>
            <input type="password" name="current_password" required>
          </div>
          <div class="form-field">
            <label>New Password</label>
            <input type="password" name="new_password" required minlength="8">
          </div>
          <div class="form-field">
            <label>Confirm New Password</label>
            <input type="password" name="confirm_password" required minlength="8">
          </div>
          <button type="submit" class="btn btn--solid">Update Password</button>
        </form>
      </div>
    </div>
  </div>
</section>

<?php require __DIR__ . '/includes/footer.php'; ?>
