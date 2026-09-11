<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/product_service.php';
require_once __DIR__ . '/../includes/order_service.php';
require_once __DIR__ . '/../includes/return_service.php';
require_once __DIR__ . '/../includes/contact_service.php';
auth_require_admin();

$products     = product_list(null, null, 500);
$orders       = order_list_recent(10);
$totalStock   = array_sum(array_column($products, 'stock'));
$lowStock     = product_low_stock();
$totalOrders  = count(order_list_recent(1000));
$openReturns  = count(array_filter(return_list_all(), fn($r) => $r['status'] === 'requested'));
$newMessages  = contact_unread_count();

$pageTitle = 'Admin Dashboard — SoleCraftPH';
require __DIR__ . '/../includes/header.php';
$active = 'dashboard';
require __DIR__ . '/_nav.php';
?>

<section class="section" style="padding-top:0;">
  <div class="wrap">
    <h1 class="display" style="margin-bottom:30px;">Dashboard</h1>

    <?php if (!empty($lowStock)): ?>
      <div class="dash-alert">
        <span><strong><?= count($lowStock) ?> product(s)</strong> at or below their low-stock threshold: <?= htmlspecialchars(implode(', ', array_slice(array_column($lowStock, 'name'), 0, 5))) ?><?= count($lowStock) > 5 ? '…' : '' ?></span>
        <a href="products.php" class="btn btn--sm">Review Inventory</a>
      </div>
    <?php endif; ?>

    <?php if ($openReturns > 0 || $newMessages > 0): ?>
      <div class="dash-alert" style="border-color:var(--ink);">
        <span>
          <?php if ($openReturns > 0): ?><strong><?= $openReturns ?></strong> return request(s) awaiting review.<?php endif; ?>
          <?php if ($newMessages > 0): ?> <strong><?= $newMessages ?></strong> new support message(s).<?php endif; ?>
        </span>
        <span style="display:flex;gap:10px;">
          <?php if ($openReturns > 0): ?><a href="returns.php" class="btn btn--sm">View Returns</a><?php endif; ?>
          <?php if ($newMessages > 0): ?><a href="messages.php" class="btn btn--sm">View Messages</a><?php endif; ?>
        </span>
      </div>
    <?php endif; ?>

    <div class="stat-row">
      <div><b><?= count($products) ?></b><span>Active Products</span></div>
      <div><b><?= $totalStock ?></b><span>Units in Stock</span></div>
      <div><b><?= count($lowStock) ?></b><span>Low Stock</span></div>
      <div><b><?= $totalOrders ?></b><span>Total Orders</span></div>
    </div>

    <div class="section-head">
      <div><span class="mono">Recent</span><h2 class="display" style="font-size:32px;">Latest Orders</h2></div>
      <a href="orders.php" class="btn">View All Orders</a>
    </div>

    <?php if (empty($orders)): ?>
      <div class="empty-state">No orders yet.</div>
    <?php else: ?>
      <div class="table-scroll">
      <table class="admin-table">
        <thead><tr><th>Order #</th><th>Customer</th><th>Total</th><th>Status</th><th>Date</th></tr></thead>
        <tbody>
          <?php foreach ($orders as $o): ?>
            <tr>
              <td>#<?= str_pad($o['id'], 6, '0', STR_PAD_LEFT) ?></td>
              <td><?= htmlspecialchars($o['customer_name']) ?></td>
              <td>₱<?= number_format($o['total_amount'], 2) ?></td>
              <td><?= htmlspecialchars(ucfirst($o['status'])) ?></td>
              <td><?= htmlspecialchars($o['created_at']) ?></td>
            </tr>
          <?php endforeach; ?>
        </tbody>
      </table>
      </div>
    <?php endif; ?>
  </div>
</section>

<?php require __DIR__ . '/../includes/footer.php'; ?>
