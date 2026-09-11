<?php
/**
 * Who built this. A flat list of the five of us, in the order the group uses.
 *
 * The names live here rather than in the database on purpose: this is not
 * content the shop owner edits between campaigns, it is a fact about the
 * project, and a cms_pages row would mean an admin screen and a migration for
 * something that changes once a term.
 */
require_once __DIR__ . '/config/app.php';

$groupName = 'Group 9';
$developers = [
    'Brian Ballano',
    'Erika Joan Del Rosario',
    'John Lawrence Balitos',
    'Keanu Florenz Licup',
    'Paul Francis Balboa',
];

/**
 * First initial and last initial, so "Erika Joan Del Rosario" reads ER and not
 * EJDR. Derived rather than typed out: a name and its monogram cannot drift
 * apart if only one of them exists.
 */
function developer_monogram(string $name): string
{
    $parts = preg_split('/\s+/', trim($name)) ?: [];
    if (count($parts) < 2) {
        return strtoupper(substr($name, 0, 2));
    }
    return strtoupper(substr($parts[0], 0, 1) . substr($parts[count($parts) - 1], 0, 1));
}

$pageTitle = 'The Developers — SoleCraftPH';
require __DIR__ . '/includes/header.php';
?>

<style>
  /* Page-specific, so it sits here rather than in style.css — the same call
     the homepage hero makes. Nothing else on the site uses a monogram tile. */
  .devs{
    display:grid;
    /* Five across on a wide screen, and it reflows on its own down to one.
       No breakpoint list: the column count is whatever fits at 200px. */
    grid-template-columns:repeat(auto-fit,minmax(200px,1fr));
    gap:18px;
  }
  .dev{
    border:1.5px solid var(--stone);
    background:#fff;
    padding:26px 18px;
    text-align:center;
  }
  .dev__mark{
    width:78px;height:78px;margin:0 auto 18px;
    border-radius:50%;
    background:var(--ink);color:#fff;
    display:flex;align-items:center;justify-content:center;
    font-family:'Bebas Neue',sans-serif;font-size:30px;letter-spacing:1.5px;
  }
  .dev__name{
    font-family:'Bebas Neue',sans-serif;
    font-size:21px;line-height:1.15;letter-spacing:.5px;
    /* Long names wrap to two lines; without this the cards in a row end up
       different heights and the monograms stop lining up. */
    min-height:2.3em;
    display:flex;align-items:center;justify-content:center;
  }
  .dev__rule{
    width:28px;height:3px;margin:14px auto 0;
    background:var(--blaze);
  }
</style>

<header class="pagehead">
  <div class="wrap">
    <h1 class="display">The Developers</h1>
    <p><?= htmlspecialchars($groupName) ?> — the five of us who built SoleCraftPH, from the storefront and the admin panel to the Android app.</p>
  </div>
</header>

<section class="section">
  <div class="wrap">
    <div class="devs">
      <?php foreach ($developers as $name): ?>
        <div class="dev">
          <div class="dev__mark" aria-hidden="true"><?= htmlspecialchars(developer_monogram($name)) ?></div>
          <div class="dev__name"><?= htmlspecialchars($name) ?></div>
          <div class="dev__rule"></div>
        </div>
      <?php endforeach; ?>
    </div>

    <p class="mono" style="margin-top:34px;color:var(--gray);">
      <?= count($developers) ?> members &middot; <?= htmlspecialchars($groupName) ?>
    </p>
  </div>
</section>

<?php require __DIR__ . '/includes/footer.php'; ?>
