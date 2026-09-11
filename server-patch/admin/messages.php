<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/contact_service.php';
require_once __DIR__ . '/../includes/ui_helpers.php';
auth_require_admin();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $id = (int) ($_POST['message_id'] ?? 0);
    contact_set_status($id, $_POST['status'] ?? 'read');
    header('Location: messages.php');
    exit;
}

$messages = contact_list();

$pageTitle = 'Messages — Admin — SoleCraftPH';
require __DIR__ . '/../includes/header.php';
$active = 'messages';
require __DIR__ . '/_nav.php';
?>

<section class="section" style="padding-top:0;">
  <div class="wrap">
    <h1 class="display" style="margin-bottom:30px;">Support Messages</h1>

    <?php if (empty($messages)): ?>
      <div class="empty-state">No messages yet.</div>
    <?php else: ?>
      <?php foreach ($messages as $m): ?>
        <div class="panel" style="margin-bottom:16px;">
          <div class="section-head" style="margin-bottom:14px;">
            <div>
              <span class="mono"><?= htmlspecialchars($m['created_at']) ?></span>
              <h3 class="display" style="font-size:22px;"><?= htmlspecialchars($m['subject']) ?></h3>
            </div>
            <?= render_status_badge($m['status']) ?>
          </div>
          <p style="margin-bottom:10px;"><strong><?= htmlspecialchars($m['name']) ?></strong> &lt;<?= htmlspecialchars($m['email']) ?>&gt;</p>
          <p style="color:#3d3b36;line-height:1.6;margin-bottom:16px;"><?= nl2br(htmlspecialchars($m['message'])) ?></p>
          <form method="post" action="messages.php" style="display:flex;gap:10px;">
            <input type="hidden" name="message_id" value="<?= $m['id'] ?>">
            <select name="status" style="padding:8px;border:1.5px solid var(--ink);font-size:12px;">
              <option value="new" <?= $m['status'] === 'new' ? 'selected' : '' ?>>New</option>
              <option value="read" <?= $m['status'] === 'read' ? 'selected' : '' ?>>Read</option>
              <option value="resolved" <?= $m['status'] === 'resolved' ? 'selected' : '' ?>>Resolved</option>
            </select>
            <button type="submit" class="btn btn--sm">Save</button>
            <a href="mailto:<?= htmlspecialchars($m['email']) ?>" class="btn btn--sm">Reply by Email</a>
          </form>
        </div>
      <?php endforeach; ?>
    <?php endif; ?>
  </div>
</section>

<?php require __DIR__ . '/../includes/footer.php'; ?>
