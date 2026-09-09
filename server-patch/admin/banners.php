<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/cms_service.php';
require_once __DIR__ . '/../includes/audit_service.php';
auth_require_admin();

$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $formAction = $_POST['form_action'] ?? '';
    if ($formAction === 'create') {
        $title = trim($_POST['title'] ?? '');
        $subtitle = trim($_POST['subtitle'] ?? '');
        $link = trim($_POST['link_url'] ?? '');
        $sort = (int) ($_POST['sort_order'] ?? 0);

        $upload = banner_handle_image_upload();
        if ($upload['error']) {
            // Shown rather than swallowed: without this, a rejected image
            // quietly created a text banner and the picture simply never
            // appeared, with nothing on screen saying why.
            $error = $upload['error'];
        } elseif ($title !== '') {
            banner_create($title, $subtitle, $link, $sort, $upload['url']);
            audit_log('Banner created', $title . ($upload['url'] !== '' ? ' (with image)' : ''));
        }
    } elseif ($formAction === 'toggle') {
        banner_toggle((int) ($_POST['banner_id'] ?? 0));
        audit_log('Banner toggled', 'Banner #' . ($_POST['banner_id'] ?? ''));
    } elseif ($formAction === 'delete') {
        banner_delete((int) ($_POST['banner_id'] ?? 0));
        audit_log('Banner deleted', 'Banner #' . ($_POST['banner_id'] ?? ''));
    }

    // Redirect only on success, so a rejected upload can say so instead of
    // being lost to the redirect.
    if ($error === '') {
        header('Location: banners.php');
        exit;
    }
}

$banners = banner_list_all();

$pageTitle = 'Banners — Admin — SoleCraftPH';
require __DIR__ . '/../includes/header.php';
$active = 'banners';
require __DIR__ . '/_nav.php';
?>

<section class="section" style="padding-top:0;">
  <div class="wrap">
    <h1 class="display" style="margin-bottom:30px;">Homepage Banners &amp; Promotions</h1>
    <p class="mono" style="color:var(--gray);margin-bottom:30px;">
      With an image, a banner fills the top of the homepage as a promo. Without one, it appears as a thin text strip.
    </p>

    <div class="panel" style="max-width:640px;margin-bottom:40px;">
      <h3 class="display" style="font-size:22px;margin-bottom:16px;">Add Banner</h3>
      <?php if ($error): ?><div class="alert alert--error"><?= htmlspecialchars($error) ?></div><?php endif; ?>
      <form method="post" action="banners.php" enctype="multipart/form-data">
        <input type="hidden" name="form_action" value="create">
        <div class="form-grid">
          <div class="form-field full"><label>Title *</label><input type="text" name="title" required placeholder="Mid-Season Sale"></div>
          <div class="form-field full">
            <label>Banner image</label>
            <input type="file" name="image" accept="image/jpeg,image/png,image/webp,image/gif">
            <span class="mono" style="color:var(--gray);display:block;margin-top:6px;">
              Optional. Wide artwork, around 1920&times;600. Use the same size for every promo banner — the first one sets the height and the rest are matched to it.
            </span>
          </div>
          <div class="form-field full"><label>Subtitle</label><input type="text" name="subtitle" placeholder="Optional — shown on text banners only"></div>
          <div class="form-field"><label>Link URL</label><input type="text" name="link_url" placeholder="Optional — /index.php?category=..."></div>
          <div class="form-field"><label>Sort Order</label><input type="number" name="sort_order" value="0"></div>
        </div>
        <button type="submit" class="btn btn--solid">Add Banner</button>
      </form>
    </div>

    <?php if (empty($banners)): ?>
      <div class="empty-state">No banners yet.</div>
    <?php else: ?>
      <div class="table-scroll">
      <table class="admin-table">
        <thead><tr><th>Image</th><th>Title</th><th>Subtitle</th><th>Links to</th><th>Order</th><th>Status</th><th>Actions</th></tr></thead>
        <tbody>
          <?php foreach ($banners as $b): ?>
            <?php $img = $b['image_url'] ?? ''; ?>
            <tr style="<?= $b['is_active'] ? '' : 'opacity:.55;' ?>">
              <td>
                <?php if ($img !== ''): ?>
                  <img src="<?= BASE_PATH ?>/<?= htmlspecialchars($img) ?>" alt="" style="width:120px;height:auto;display:block;border:1px solid var(--stone);">
                <?php else: ?>
                  <span class="mono" style="color:var(--gray);">Text only</span>
                <?php endif; ?>
              </td>
              <td><?= htmlspecialchars($b['title']) ?></td>
              <td><?= htmlspecialchars($b['subtitle'] ?: '—') ?></td>
              <td><span class="mono"><?= htmlspecialchars($b['link_url'] ?: '—') ?></span></td>
              <td><?= (int) $b['sort_order'] ?></td>
              <td><span class="mono"><?= $b['is_active'] ? 'Active' : 'Inactive' ?></span></td>
              <td>
                <div style="display:flex;gap:14px;">
                  <form method="post" action="banners.php"><input type="hidden" name="form_action" value="toggle"><input type="hidden" name="banner_id" value="<?= $b['id'] ?>"><button type="submit" class="mono" style="background:none;border:none;cursor:pointer;font-weight:700;"><?= $b['is_active'] ? 'Deactivate' : 'Activate' ?></button></form>
                  <form method="post" action="banners.php" onsubmit="return confirm('Delete this banner?');"><input type="hidden" name="form_action" value="delete"><input type="hidden" name="banner_id" value="<?= $b['id'] ?>"><button type="submit" class="link-remove" style="background:none;border:none;cursor:pointer;">Delete</button></form>
                </div>
              </td>
            </tr>
          <?php endforeach; ?>
        </tbody>
      </table>
      </div>
    <?php endif; ?>
  </div>
</section>

<?php require __DIR__ . '/../includes/footer.php'; ?>
