<?php
require_once __DIR__ . '/config/app.php';
require_once __DIR__ . '/includes/product_service.php';
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/wishlist_service.php';
require_once __DIR__ . '/includes/cms_service.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['action'] ?? '') === 'toggle_wishlist' && auth_is_logged_in() && !auth_is_admin()) {
    wishlist_toggle((int) $_SESSION['user_id'], (int) ($_POST['product_id'] ?? 0));
    header('Location: ' . ($_SERVER['HTTP_REFERER'] ?? (BASE_PATH . '/index.php')));
    exit;
}

$wishlistIds = (auth_is_logged_in() && !auth_is_admin()) ? wishlist_product_ids((int) $_SESSION['user_id']) : [];
$activeBanners = banner_list_active();

$search      = trim($_GET['q'] ?? '');
$category    = trim($_GET['category'] ?? '');
$subcategory = trim($_GET['subcategory'] ?? '');

if ($search !== '') {
    $products = product_search($search);
} else {
    $products = product_list($category ?: null, $subcategory ?: null);
}
$categories = product_categories();
$subcategoryMap = product_subcategory_map($category ?: null);
$subcategoriesForCategory = $category !== '' ? ($subcategoryMap[$category] ?? []) : [];
$pageTitle = 'SoleCraftPH — Footwear, Done Right';
require __DIR__ . '/includes/header.php';

// --- Hero media, checked in order of priority:
//  1) assets/media/hero.mp4            -> looping promo video
//  2) assets/media/hero/*.jpg|png|...  -> your own promo photos (independent of products)
//  3) newest product photos            -> automatic fallback slideshow
//  4) nothing found                    -> plain text banner, no media
$heroVideoExists = is_file(__DIR__ . '/assets/media/hero.mp4');

$customHeroFiles = [];
if (!$heroVideoExists) {
    $customHeroFiles = glob(__DIR__ . '/assets/media/hero/*.{jpg,jpeg,png,webp,gif}', GLOB_BRACE) ?: [];
    natsort($customHeroFiles);
}

if (!$heroVideoExists && !empty($customHeroFiles)) {
    // Your own promo images — independent of any product.
    $heroSlides = array_map(static function (string $path) {
        return ['image_url' => BASE_PATH . '/assets/media/hero/' . rawurlencode(basename($path)), 'name' => ''];
    }, array_values($customHeroFiles));
} elseif (!$heroVideoExists) {
    // Fallback: auto-slideshow of the newest product photos.
    $heroSlides = array_map(static function (array $p) {
        return ['image_url' => product_image_url($p), 'name' => $p['name']];
    }, product_hero_images(6));
} else {
    $heroSlides = [];
}
$heroHasMedia = $heroVideoExists || !empty($heroSlides);

$heroSlideCount = count($heroSlides);
$heroSegment = 5;   // seconds each photo stays fully visible (incl. its own fade)
$heroFade    = 1.1; // seconds of crossfade
$heroTotal   = max($heroSegment, $heroSlideCount * $heroSegment);
if ($heroSlideCount > 1) {
    $heroFadeInPct = round($heroFade / $heroTotal * 100, 3);
    $heroHoldPct   = round(($heroSegment - $heroFade) / $heroTotal * 100, 3);
    $heroOutPct    = round($heroSegment / $heroTotal * 100, 3);
}
?>

<?php if (!empty($activeBanners)): ?>
<div class="banner-strip">
  <div class="wrap">
    <?php foreach ($activeBanners as $b): ?>
      <?php if (!empty($b['link_url'])): ?>
        <a href="<?= htmlspecialchars($b['link_url']) ?>"><?= htmlspecialchars($b['title']) ?></a>
      <?php else: ?>
        <span style="font-family:'Bebas Neue',sans-serif;font-size:18px;color:#fff;"><?= htmlspecialchars($b['title']) ?></span>
      <?php endif; ?>
      <?php if (!empty($b['subtitle'])): ?><span><?= htmlspecialchars($b['subtitle']) ?></span><?php endif; ?>
    <?php endforeach; ?>
  </div>
</div>
<?php endif; ?>

<header class="pagehead<?= $heroHasMedia ? ' pagehead--media' : '' ?>">
  <?php if ($heroVideoExists): ?>
    <div class="hero-media">
      <video autoplay muted loop playsinline>
        <source src="<?= BASE_PATH ?>/assets/media/hero.mp4" type="video/mp4">
      </video>
    </div>
    <div class="hero-overlay"></div>
  <?php elseif ($heroSlideCount > 0): ?>
    <?php if ($heroSlideCount > 1): ?>
      <style>
        @keyframes heroFade{
          0%{opacity:0;}
          <?= $heroFadeInPct ?>%{opacity:1;}
          <?= $heroHoldPct ?>%{opacity:1;}
          <?= $heroOutPct ?>%{opacity:0;}
          100%{opacity:0;}
        }
      </style>
    <?php endif; ?>
    <div class="hero-media">
      <?php foreach ($heroSlides as $i => $hp): ?>
        <div class="hero-slide"
             style="background-image:url('<?= htmlspecialchars($hp['image_url']) ?>');<?= $heroSlideCount > 1 ? " animation:heroFade {$heroTotal}s ease-in-out infinite; animation-delay:" . ($i * $heroSegment) . "s;" : 'opacity:1;' ?>">
        </div>
      <?php endforeach; ?>
    </div>
    <div class="hero-overlay"></div>
  <?php endif; ?>

  <div class="wrap">
    <span class="mono" style="color:var(--blaze)">SS26 Collection</span>
    <h1 class="display" style="margin-top:14px;">Built for every step you take.</h1>
    <p>Authentic footwear, sourced right and priced fair — browse the full catalog below.</p>

    <form class="searchbar" method="get" action="<?= BASE_PATH ?>/index.php">
      <input type="text" name="q" placeholder="Search shoes, e.g. 'trail' or 'running'" value="<?= htmlspecialchars($search) ?>">
      <button type="submit">Search</button>
    </form>

    <div class="filters">
      <a href="<?= BASE_PATH ?>/index.php" class="<?= $category === '' && $search === '' ? 'active' : '' ?>">All</a>
      <?php foreach ($categories as $cat): ?>
        <a href="<?= BASE_PATH ?>/index.php?category=<?= urlencode($cat) ?>" class="<?= $category === $cat ? 'active' : '' ?>"><?= htmlspecialchars($cat) ?></a>
      <?php endforeach; ?>
    </div>

    <?php if ($category !== '' && !empty($subcategoriesForCategory)): ?>
      <div class="filters filters--sub">
        <a href="<?= BASE_PATH ?>/index.php?category=<?= urlencode($category) ?>" class="<?= $subcategory === '' ? 'active' : '' ?>">All <?= htmlspecialchars($category) ?></a>
        <?php foreach ($subcategoriesForCategory as $sub): ?>
          <a href="<?= BASE_PATH ?>/index.php?category=<?= urlencode($category) ?>&subcategory=<?= urlencode($sub) ?>" class="<?= $subcategory === $sub ? 'active' : '' ?>"><?= htmlspecialchars($sub) ?></a>
        <?php endforeach; ?>
      </div>
    <?php endif; ?>
  </div>
</header>

<section class="section">
  <div class="wrap">
    <div class="section-head">
      <div>
        <span class="mono">Catalog</span>
        <h2 class="display"><?= $search !== '' ? 'Results for "' . htmlspecialchars($search) . '"' : htmlspecialchars($subcategory ?: ($category ?: 'All Products')) ?></h2>
      </div>
      <p style="max-width:340px;font-size:14px;color:var(--gray);"><?= count($products) ?> item(s) found.</p>
    </div>

    <?php if (empty($products)): ?>
      <div class="empty-state">No products matched your search.</div>
    <?php else: ?>
      <div class="products">
        <?php foreach ($products as $p): $price = product_display_price($p); $img = product_image_url($p); ?>
          <article class="card">
            <a class="card__frame" href="<?= BASE_PATH ?>/product.php?id=<?= $p['id'] ?>" style="--accent:#111111;color:#111111;" aria-label="View <?= htmlspecialchars($p['name']) ?>">
              <?php if ($p['badge']): ?><span class="card__badge <?= $p['sale_price'] ? 'card__badge--sale' : '' ?>"><?= htmlspecialchars($p['badge']) ?></span><?php endif; ?>
              <?php if ($p['stock'] < 1): ?><span class="card__badge card__badge--out" style="left:auto;right:14px;">Sold Out</span><?php endif; ?>
              <?php if ($img): ?>
                <img src="<?= htmlspecialchars($img) ?>" alt="<?= htmlspecialchars($p['name']) ?>" class="card__photo" loading="lazy">
              <?php else: ?>
                <svg viewBox="0 0 300 160"><use href="#shoe"/></svg>
              <?php endif; ?>
            </a>
            <?php if (auth_is_logged_in() && !auth_is_admin()): ?>
              <form method="post" action="<?= BASE_PATH ?>/index.php">
                <input type="hidden" name="action" value="toggle_wishlist">
                <input type="hidden" name="product_id" value="<?= $p['id'] ?>">
                <button type="submit" class="card__wishlist <?= in_array($p['id'], $wishlistIds, true) ? 'is-active' : '' ?>" aria-label="Toggle wishlist" title="Toggle wishlist">
                  <?= in_array($p['id'], $wishlistIds, true) ? '♥' : '♡' ?>
                </button>
              </form>
            <?php endif; ?>
            <div class="card__body">
              <div class="card__cat mono"><?= htmlspecialchars($p['category']) ?><?= !empty($p['subcategory']) ? ' · ' . htmlspecialchars($p['subcategory']) : '' ?></div>
              <div class="card__name"><a href="<?= BASE_PATH ?>/product.php?id=<?= $p['id'] ?>"><?= htmlspecialchars($p['name']) ?></a></div>
              <div class="card__row">
                <span class="card__price">
                  <?php if ($p['sale_price']): ?><s>₱<?= number_format($p['price'], 2) ?></s><?php endif; ?>
                  ₱<?= number_format($price, 2) ?>
                </span>
                <?php // A grid card has nowhere to pick a size, and the cart now
                      // needs one — so send shoppers to the product page instead
                      // of posting an add that would only be rejected. ?>
                <?php if ($p['stock'] < 1): ?>
                  <button type="button" class="card__add" disabled>Unavailable</button>
                <?php else: ?>
                  <a class="card__add" style="display:inline-block;text-align:center;text-decoration:none;"
                     href="<?= BASE_PATH ?>/product.php?id=<?= $p['id'] ?>">Choose Size</a>
                <?php endif; ?>
              </div>
            </div>
          </article>
        <?php endforeach; ?>
        <?php
          // The grid's hairlines are drawn by the container's dark background
          // showing through the gap — an incomplete last row leaves an empty
          // cell with nothing covering that background, which reads as a
          // solid black tile. Pad the row with blank filler cards instead.
          $fillers = (3 - (count($products) % 3)) % 3;
          for ($i = 0; $i < $fillers; $i++): ?>
          <div class="card" aria-hidden="true"></div>
        <?php endfor; ?>
      </div>
    <?php endif; ?>
  </div>
</section>

<?php require __DIR__ . '/includes/footer.php'; ?>
