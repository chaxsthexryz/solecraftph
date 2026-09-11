<footer>
  <div class="wrap">
    <div class="foot__grid">
      <div>
        <div class="foot__brand">SOLE<span>CRAFT</span>PH</div>
        <p>Authentic footwear for the way Filipinos move — sourced right, priced fair, and always in stock when it matters.</p>
      </div>
      <div class="foot__col">
        <h4>Shop</h4>
        <a href="<?= BASE_PATH ?>/index.php?category=<?= urlencode('Athletic & Performance Footwear') ?>">Athletic & Performance</a>
        <a href="<?= BASE_PATH ?>/index.php?category=<?= urlencode('Casual & Lifestyle Footwear') ?>">Casual & Lifestyle</a>
        <a href="<?= BASE_PATH ?>/index.php?category=<?= urlencode('Formal & Dress Footwear') ?>">Formal & Dress</a>
      </div>
      <div class="foot__col">
        <h4>Company</h4>
        <a href="<?= BASE_PATH ?>/page.php?slug=about">About Us</a>
        <a href="<?= BASE_PATH ?>/page.php?slug=faq">FAQs</a>
        <a href="<?= BASE_PATH ?>/page.php?slug=privacy">Privacy Policy</a>
        <a href="<?= BASE_PATH ?>/developers.php">The Developers</a>
      </div>
      <div class="foot__col">
        <h4>Help</h4>
        <a href="<?= BASE_PATH ?>/cart.php">Cart</a>
        <a href="<?= BASE_PATH ?>/contact.php">Contact Support</a>
      </div>
    </div>
    <div class="wrap foot__bottom" style="padding-left:0;padding-right:0;">
      <span>&copy; <?= date('Y') ?> SoleCraftPH. All rights reserved.</span>
      <span class="mono">Made in the Philippines</span>
    </div>
  </div>
</footer>

<script>
/* "Add to Cart" without leaving the page: intercept the form, post it
   in the background, show a toast, update the nav cart count. */
(function () {
  function showToast(message, ok) {
    if (!message) return;
    var toast = document.createElement('div');
    toast.className = 'toast' + (ok === false ? ' toast--error' : '');
    toast.textContent = message;
    document.body.appendChild(toast);
    requestAnimationFrame(function () { toast.classList.add('is-visible'); });
    setTimeout(function () {
      toast.classList.remove('is-visible');
      setTimeout(function () { toast.remove(); }, 300);
    }, 2600);
  }

  document.addEventListener('submit', function (e) {
    var form = e.target;
    if (!(form instanceof HTMLFormElement)) return;

    var actionField = form.querySelector('input[name="action"]');
    if (!actionField || actionField.value !== 'add') return;
    if (!/\/cart\.php(\?.*)?$/.test(form.getAttribute('action') || '')) return;

    e.preventDefault();

    var btn = form.querySelector('button[type="submit"]');
    var originalLabel = btn ? btn.textContent : '';
    if (btn) { btn.disabled = true; btn.textContent = 'Adding…'; }

    fetch(form.getAttribute('action'), {
      method: 'POST',
      body: new FormData(form),
      headers: { 'X-Requested-With': 'XMLHttpRequest' }
    })
      .then(function (r) { return r.json(); })
      .then(function (data) {
        showToast(data.message, data.ok);
        var countEl = document.getElementById('navCartCount');
        if (countEl && typeof data.cart_count !== 'undefined') {
          countEl.textContent = data.cart_count;
        }
      })
      .catch(function () {
        showToast('Something went wrong. Please try again.', false);
      })
      .finally(function () {
        if (btn) { btn.disabled = false; btn.textContent = originalLabel; }
      });
  });
})();
</script>

</body>
</html>
