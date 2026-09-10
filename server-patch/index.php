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
// One banners table, two presentations. A row with an image is a full-width
// promo at the top of the page; a row without one is the thin text strip it
// has always been. Split here so an image banner does not appear as both.
$activeBanners = banner_list_active();
$promoBanners  = [];
foreach ($activeBanners as $i => $b) {
    // Null-coalesced because this has to keep rendering on a database where
    // upgrade_v10_banner_images.sql has not run yet.
    if (($b['image_url'] ?? '') !== '') {
        $promoBanners[] = $b;
        unset($activeBanners[$i]);
    }
}
$activeBanners = array_values($activeBanners);

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

// --- What can appear above the catalog, in priority order:
//  1) active banners carrying an image  -> promo band, managed in admin
//  2) assets/media/hero/*.jpg|png|...   -> promo band, no database needed
//  3) nothing                           -> the type hero alone
//
// The looping hero.mp4 branch is gone. There was never a video, and a branch
// that has never once been true is a branch nobody has ever tested.
$customHeroFiles = glob(__DIR__ . '/assets/media/hero/*.{jpg,jpeg,png,webp,gif}', GLOB_BRACE) ?: [];
natsort($customHeroFiles);

// Promo banners get their own band above the page header rather than being
// used as wallpaper behind it.
//
// A promotional image already carries its own headline, discount and call to
// action. The hero treatment below would crop it to a tall box, drop a 72%
// black scrim over it, and then print our own heading, search box and category
// pills on top — burying the thing it is advertising under the site chrome.
// Shown whole instead, at its own aspect ratio, with the header underneath
// going back to plain text on paper.
// Banners uploaded in admin come first: they carry a title for the alt text,
// a link, an order and an on/off switch, and the shop owner can change them
// without touching the server.
$promoSlides = [];
foreach ($promoBanners as $b) {
    $promoSlides[] = [
        'url'  => BASE_PATH . '/' . $b['image_url'],
        'alt'  => $b['title'],
        'link' => $b['link_url'] ?: '',
    ];
}

// Failing that, anything dropped straight into assets/media/hero/. No link and
// no ordering beyond the filename, but it needs no database and no admin
// login — which is the point of keeping it: it is the way back in when the
// panel is unreachable.
if (empty($promoSlides) && !empty($customHeroFiles)) {
    $promoSlides = array_map(static function (string $path): array {
        $file = basename($path);
        return [
            'url' => BASE_PATH . '/assets/media/hero/' . rawurlencode($file),
            // Best effort, and better than nothing: a screen reader gets
            // "Mid Season Sale 50 Off" from mid-season-sale-50-off.jpg. Name
            // the files in words and the alt text writes itself.
            'alt'  => ucwords(str_replace(['-', '_'], ' ', pathinfo($file, PATHINFO_FILENAME))),
            'link' => '',
        ];
    }, array_values($customHeroFiles));
}

// The hero is type alone now: no product beside the copy, no photo behind it.
//
// Both earlier attempts are gone for the same reason. The slideshow-behind-text
// needed a 72% black scrim to stay legible and still turned on which shoe
// happened to be newest. The product-on-paper zone fixed the legibility but
// filled the most valuable space on the site with a catalog photo the visitor
// is about to scroll past anyway.
//
// Type holds this on its own until there is a real image worth the space. The
// promo band above takes any campaign artwork; this stays the permanent voice.

// Fade timing serves the promo band alone.
$fadeCount   = count($promoSlides);
$heroSegment = 5;   // seconds each photo stays fully visible (incl. its own fade)
$heroFade    = 1.1; // seconds of crossfade
$heroTotal   = max($heroSegment, $fadeCount * $heroSegment);
if ($fadeCount > 1) {
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

<?php if (!empty($promoSlides)): ?>
  <style>
    /* Only the homepage has this band, so it lives here rather than in
       style.css — one fewer file to keep in step. */
    .promo{background:var(--ink);border-bottom:1.5px solid var(--ink);}
    /* The first image sits in normal flow and sets the band's height; the rest
       are stacked over it. That is what makes this responsive without picking
       an aspect ratio: the band is exactly as tall as the artwork at whatever
       width the screen happens to be, so a promo is never cropped and never
       letterboxed. */
    .promo__stack{position:relative;}
    .promo__slide{display:block;position:relative;}
    .promo__slide img{display:block;width:100%;height:auto;}
    .promo__slide--over{position:absolute;inset:0;opacity:0;}
    .promo__slide--over img{height:100%;object-fit:cover;}
    @media (prefers-reduced-motion:reduce){
      /* Crossfading artwork under someone who asked for less motion is exactly
         the thing that setting is for. They get the first banner, held. */
      .promo__slide{animation:none!important;}
      .promo__slide--over{display:none;}
    }
  </style>
  <?php if (count($promoSlides) > 1): ?>
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
  <section class="promo">
    <div class="promo__stack">
      <?php foreach ($promoSlides as $i => $slide): ?>
        <?php
          // A linked banner is an <a>, an unlinked one a <div> — same class, so
          // the stacking and the fade do not care which it is. The anchor wraps
          // the image rather than the image being the anchor, because the
          // first slide has to stay in normal flow to give the band its height.
          $tag   = $slide['link'] !== '' ? 'a' : 'div';
          $attrs = $slide['link'] !== '' ? ' href="' . htmlspecialchars($slide['link']) . '"' : '';
          if (count($promoSlides) > 1) {
              $attrs .= ' style="animation:heroFade ' . $heroTotal . 's ease-in-out infinite;'
                     . 'animation-delay:' . ($i * $heroSegment) . 's;"';
          }
        ?>
        <<?= $tag ?> class="promo__slide<?= $i > 0 ? ' promo__slide--over' : '' ?>"<?= $attrs ?>>
          <img src="<?= htmlspecialchars($slide['url']) ?>"
               alt="<?= htmlspecialchars($slide['alt']) ?>"<?= $i > 0 ? ' loading="lazy"' : '' ?>>
        </<?= $tag ?>>
      <?php endforeach; ?>
    </div>
  </section>
<?php endif; ?>

<style>
  /* THE TYPE HERO
     One ink field, the headline carrying it alone. No photograph behind the
     words and no product beside them.

     Inline here rather than in style.css because .pagehead is shared with the
     cart and checkout headers, and only this page gets the treatment. Same
     reasoning as the promo band above.

     These selectors outrank their .pagehead counterparts by source order, not
     by weight: the stylesheet is linked in <head>, this block comes after. */
  .splithero{
    background:var(--ink);
    padding:0;                 /* .pagehead sets 50px 0 40px */
    overflow:hidden;
  }
  .splithero__copy{
    display:flex;
    flex-direction:column;
    justify-content:center;
    /* Height comes from a min, not an aspect-ratio: the chip rows grow when a
       category is open, and a fixed ratio would clip them. */
    min-height:clamp(260px,24vw,360px);
    /* Matches .wrap's 1280 + 40 so the headline starts on the same line as the
       catalog heading below it, while the ink field still runs edge to edge. */
    max-width:1280px;
    margin:0 auto;
    padding:clamp(30px,3.4vw,54px) 40px;
  }
  /* With nothing beside it the headline has the whole measure, so it can carry
     the weight the split hero borrowed from the photograph. */
  .splithero__copy h1{color:#fff;font-size:clamp(38px,6.4vw,88px);max-width:16ch;}
  .splithero__copy p{color:#B9B2A8;max-width:52ch;font-size:15px;}
  .splithero .searchbar{margin-top:18px;max-width:420px;border-color:#fff;}
  .splithero .searchbar input{color:#fff;}
  .splithero .searchbar input::placeholder{color:rgba(255,255,255,.65);}
  .splithero .searchbar button{background:#fff;color:var(--ink);border-left-color:#fff;}
  .splithero .searchbar button:hover{background:var(--blaze);color:#fff;}
  .splithero .filters{margin:20px 0 0;}
  .splithero .filters a{border-color:#fff;color:#fff;}
  .splithero .filters a.active,.splithero .filters a:hover{background:#fff;color:var(--ink);}
  .splithero .filters--sub{margin:8px 0 0;}
  .splithero .filters--sub a{border-color:rgba(255,255,255,.7);color:#fff;}
  .splithero .filters--sub a.active,.splithero .filters--sub a:hover{background:#fff;color:var(--ink);}

  /* The red the product zone carried now sits under the whole field, holding
     the accent without needing a picture to sit beside. */
  .splithero{border-bottom:3px solid var(--blaze);}

  @media (max-width:860px){
    .splithero__copy{min-height:0;padding:26px 20px 30px;}
  }
</style>

<header class="pagehead splithero">
  <div class="splithero__copy">
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
