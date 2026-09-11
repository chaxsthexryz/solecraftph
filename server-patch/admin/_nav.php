<?php
require_once __DIR__ . '/../includes/notification_service.php';
$__adminUnread = notification_unread_count_for_admins();
?>
<div class="admin-nav wrap">
  <a href="dashboard.php" class="<?= $active === 'dashboard' ? 'active' : '' ?>">Dashboard</a>
  <a href="products.php" class="<?= $active === 'products' ? 'active' : '' ?>">Inventory</a>
  <a href="add_product.php" class="<?= $active === 'add_product' ? 'active' : '' ?>">Add Product</a>
  <a href="orders.php" class="<?= $active === 'orders' ? 'active' : '' ?>">Orders</a>
  <a href="returns.php" class="<?= $active === 'returns' ? 'active' : '' ?>">Returns</a>
  <a href="reviews.php" class="<?= $active === 'reviews' ? 'active' : '' ?>">Reviews</a>
  <a href="customers.php" class="<?= $active === 'customers' ? 'active' : '' ?>">Customers</a>
  <a href="admins.php" class="<?= $active === 'admins' ? 'active' : '' ?>">Admins</a>
  <a href="reports.php" class="<?= $active === 'reports' ? 'active' : '' ?>">Reports</a>
  <a href="cms.php" class="<?= $active === 'cms' ? 'active' : '' ?>">Content</a>
  <a href="banners.php" class="<?= $active === 'banners' ? 'active' : '' ?>">Banners</a>
  <a href="settings.php" class="<?= $active === 'settings' ? 'active' : '' ?>">Settings</a>
  <a href="messages.php" class="<?= $active === 'messages' ? 'active' : '' ?>">Messages</a>
  <a href="notifications.php" class="<?= $active === 'notifications' ? 'active' : '' ?>">Notifications<?= $__adminUnread > 0 ? ' <span class="notif-dot"></span>' : '' ?></a>
  <a href="audit_log.php" class="<?= $active === 'audit' ? 'active' : '' ?>">Audit Trail</a>
  <a href="logout.php" style="margin-left:auto;">Log Out (<?= htmlspecialchars($_SESSION['username'] ?? '') ?>)</a>
</div>
