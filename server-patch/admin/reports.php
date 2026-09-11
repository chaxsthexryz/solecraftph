<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/order_service.php';
auth_require_admin();

$days = (int) ($_GET['days'] ?? 30);
$days = in_array($days, [7, 30, 90], true) ? $days : 30;

$summary = order_sales_summary();
$byDay = order_sales_by_day($days);
$topProducts = order_top_products(8);
$topCustomers = order_top_customers(8);

$maxRevenue = 0.01;
foreach ($byDay as $d) {
    $maxRevenue = max($maxRevenue, (float) $d['revenue']);
}
$maxUnits = 1;
foreach ($topProducts as $p) {
    $maxUnits = max($maxUnits, (int) $p['units_sold']);
}

$pageTitle = 'Reports — Admin — SoleCraftPH';
require __DIR__ . '/../includes/header.php';
$active = 'reports';
require __DIR__ . '/_nav.php';
?>

<section class="section" style="padding-top:0;">
  <div class="wrap">
    <h1 class="display" style="margin-bottom:30px;">Sales &amp; Analytics</h1>

    <div class="stat-row">
      <div><b><?= (int) $summary['total_orders'] ?></b><span>Total Orders</span></div>
      <div><b>₱<?= number_format((float) $summary['total_revenue'], 0) ?></b><span>Total Revenue</span></div>
      <div><b>₱<?= number_format((float) $summary['avg_order_value'], 0) ?></b><span>Avg Order Value</span></div>
      <div><b><?= (int) $summary['pending_count'] ?></b><span>Pending Orders</span></div>
    </div>

    <div class="section-head">
      <div><span class="mono">Revenue</span><h2 class="display" style="font-size:30px;">Last <?= $days ?> Days</h2></div>
      <div class="filters" style="margin:0;">
        <a href="reports.php?days=7" class="<?= $days === 7 ? 'active' : '' ?>">7d</a>
        <a href="reports.php?days=30" class="<?= $days === 30 ? 'active' : '' ?>">30d</a>
        <a href="reports.php?days=90" class="<?= $days === 90 ? 'active' : '' ?>">90d</a>
      </div>
    </div>

    <?php if (empty($byDay)): ?>
      <div class="empty-state">No sales in this period yet.</div>
    <?php else: ?>
      <div class="panel" style="margin-bottom:44px;">
        <div style="display:flex;align-items:flex-end;gap:6px;height:180px;">
          <?php foreach ($byDay as $d): $h = max(4, round(((float) $d['revenue'] / $maxRevenue) * 160)); ?>
            <div style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;height:100%;" title="<?= htmlspecialchars($d['day']) ?>: ₱<?= number_format((float) $d['revenue'], 2) ?>">
              <div style="width:100%;background:var(--ink);height:<?= $h ?>px;transition:background .2s;" onmouseover="this.style.background='#E2412A'" onmouseout="this.style.background='#111111'"></div>
            </div>
          <?php endforeach; ?>
        </div>
        <p class="mono" style="margin-top:10px;color:var(--gray);">Hover a bar for the exact date and revenue.</p>
      </div>
    <?php endif; ?>

    <div class="form-grid">
      <div>
        <h3 class="display" style="font-size:24px;margin-bottom:16px;">Top Products</h3>
        <?php if (empty($topProducts)): ?>
          <p class="mono" style="color:var(--gray);">No product performance data yet.</p>
        <?php else: ?>
          <?php foreach ($topProducts as $p): $w = max(6, round(((int) $p['units_sold'] / $maxUnits) * 100)); ?>
            <div style="margin-bottom:14px;">
              <div style="display:flex;justify-content:space-between;font-size:13px;margin-bottom:4px;">
                <span><?= htmlspecialchars($p['product_name']) ?></span>
                <span class="mono"><?= (int) $p['units_sold'] ?> sold · ₱<?= number_format((float) $p['revenue'], 0) ?></span>
              </div>
              <div style="background:var(--stone);height:8px;"><div style="width:<?= $w ?>%;background:var(--blaze);height:100%;"></div></div>
            </div>
          <?php endforeach; ?>
        <?php endif; ?>
      </div>

      <div>
        <h3 class="display" style="font-size:24px;margin-bottom:16px;">Top Customers</h3>
        <?php if (empty($topCustomers)): ?>
          <p class="mono" style="color:var(--gray);">No customer data yet.</p>
        <?php else: ?>
          <div class="table-scroll">
          <table class="admin-table">
            <thead><tr><th>Customer</th><th>Orders</th><th>Spent</th></tr></thead>
            <tbody>
              <?php foreach ($topCustomers as $c): ?>
                <tr>
                  <td><?= htmlspecialchars($c['customer_name']) ?><br><span class="mono" style="color:var(--gray);"><?= htmlspecialchars($c['customer_email']) ?></span></td>
                  <td><?= (int) $c['orders_count'] ?></td>
                  <td>₱<?= number_format((float) $c['total_spent'], 2) ?></td>
                </tr>
              <?php endforeach; ?>
            </tbody>
          </table>
          </div>
        <?php endif; ?>
      </div>
    </div>
  </div>
</section>

<?php require __DIR__ . '/../includes/footer.php'; ?>
