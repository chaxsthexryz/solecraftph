<?php
/**
 * Order Service
 * Handles checkout / order creation and order lookups.
 */
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/product_service.php';

/**
 * @param array $customer  ['name','email','phone','address','payment_method','user_id']
 * @param array $cartItems Cart lines. Accepts either shape:
 *                         - keyed "<product_id>|<size>" => ['product_id','size','qty', ...]
 *                         - legacy: keyed <product_id>   => ['name','price','qty']
 *                         The same shoe in two sizes is two lines.
 * @return int  the new order id
 */
function order_create(array $customer, array $cartItems): int
{
    if (empty($cartItems)) {
        throw new InvalidArgumentException('Cannot place an order with an empty cart.');
    }

    // Normalize and re-price every line from the products table before touching
    // the database. The mobile app posts its own name/price fields, and those
    // must never be what we bill — only the id, size and quantity are the
    // client's to decide.
    $lines = [];
    foreach ($cartItems as $key => $item) {
        $productId = (int) ($item['product_id'] ?? explode('|', (string) $key)[0]);
        $product   = product_find($productId);
        if (!$product) {
            throw new InvalidArgumentException('Product #' . $productId . ' is no longer available.');
        }
        $lines[] = [
            'product_id' => $productId,
            'name'       => $product['name'],
            'size'       => (string) ($item['size'] ?? ''),
            'price'      => product_display_price($product),
            'qty'        => max(1, (int) ($item['qty'] ?? 1)),
        ];
    }

    $db = db();
    $db->beginTransaction();
    try {
        /*
         * Lock the product rows and check stock BEFORE writing anything.
         *
         * Without this, two people buying the last pair at the same moment both
         * succeed: each reads stock=1, each decrements, and GREATEST(...,0)
         * quietly floors the result at zero so nothing ever looks wrong. One of
         * them gets a confirmation for a shoe that does not exist.
         *
         * SELECT ... FOR UPDATE makes the second transaction wait until the
         * first commits, so it sees stock=0 and is refused.
         *
         * Quantities are summed per product first — the same shoe in two sizes
         * is two lines but one pool of stock — and the rows are locked in
         * ascending id order so two concurrent orders containing the same
         * products in different sequences cannot deadlock against each other.
         */
        $needed = [];
        foreach ($lines as $line) {
            $needed[$line['product_id']] = ($needed[$line['product_id']] ?? 0) + $line['qty'];
        }
        ksort($needed);

        $lockStmt = $db->prepare('SELECT name, stock FROM products WHERE id = ? FOR UPDATE');
        foreach ($needed as $productId => $wanted) {
            $lockStmt->execute([$productId]);
            $row = $lockStmt->fetch();

            if (!$row) {
                throw new InvalidArgumentException('Product #' . $productId . ' is no longer available.');
            }
            if ((int) $row['stock'] < $wanted) {
                throw new RuntimeException(sprintf(
                    '%s: only %d left, and %d were requested. Please adjust your bag.',
                    $row['name'],
                    (int) $row['stock'],
                    $wanted
                ));
            }
        }

        $total = 0.0;
        foreach ($lines as $line) {
            $total += $line['price'] * $line['qty'];
        }

        $stmt = $db->prepare(
            'INSERT INTO orders (user_id, customer_name, customer_email, customer_phone, customer_address, payment_method, total_amount, status)
             VALUES (:user_id, :name, :email, :phone, :address, :payment_method, :total, "pending")'
        );
        $stmt->execute([
            ':user_id'        => $customer['user_id'] ?? null,
            ':name'           => $customer['name'],
            ':email'          => $customer['email'],
            ':phone'          => $customer['phone'],
            ':address'        => $customer['address'],
            ':payment_method' => $customer['payment_method'] ?? 'COD',
            ':total'          => $total,
        ]);
        $orderId = (int) $db->lastInsertId();

        $itemStmt = $db->prepare(
            'INSERT INTO order_items (order_id, product_id, product_name, size, unit_price, quantity, subtotal)
             VALUES (?, ?, ?, ?, ?, ?, ?)'
        );
        foreach ($lines as $line) {
            $subtotal = $line['price'] * $line['qty'];
            $itemStmt->execute([$orderId, $line['product_id'], $line['name'], $line['size'], $line['price'], $line['qty'], $subtotal]);
            product_decrement_stock($line['product_id'], $line['qty']);
        }

        $db->commit();

        // Confirmation email. After the commit and wrapped in its own try, so a
        // mail failure can never roll back or fail an order that is already paid
        // for — the customer's money matters more than their receipt.
        try {
            order_send_confirmation_email($orderId, $customer, $lines, $total);
        } catch (Throwable $mailError) {
            require_once __DIR__ . '/mail_service.php';
            mail_log('ORDER   confirmation failed for #' . $orderId . ': ' . $mailError->getMessage());
        }

        // Inventory Management: low-stock alerts, fired after the transaction commits.
        require_once __DIR__ . '/notification_service.php';
        foreach (array_unique(array_column($lines, 'product_id')) as $productId) {
            $p = product_find((int) $productId);
            if ($p && $p['is_active'] && $p['stock'] <= $p['low_stock_threshold']) {
                notification_notify_admins(
                    'Low Stock',
                    $p['name'] . ' is down to ' . $p['stock'] . ' unit(s) (threshold: ' . $p['low_stock_threshold'] . ').'
                );
            }
        }

        return $orderId;
    } catch (Throwable $e) {
        $db->rollBack();
        throw $e;
    }
}

function order_find(int $orderId): ?array
{
    $stmt = db()->prepare('SELECT * FROM orders WHERE id = ? LIMIT 1');
    $stmt->execute([$orderId]);
    $order = $stmt->fetch();
    if (!$order) {
        return null;
    }
    $itemStmt = db()->prepare('SELECT * FROM order_items WHERE order_id = ?');
    $itemStmt->execute([$orderId]);
    $order['items'] = $itemStmt->fetchAll();
    return $order;
}

function order_list_recent(int $limit = 50): array
{
    $stmt = db()->prepare('SELECT * FROM orders ORDER BY created_at DESC LIMIT ?');
    $stmt->bindValue(1, $limit, PDO::PARAM_INT);
    $stmt->execute();
    return $stmt->fetchAll();
}

/** Admin: orders list, optionally filtered by status */
function order_list_filtered(?string $status = null, int $limit = 300): array
{
    if ($status && $status !== 'all') {
        $stmt = db()->prepare('SELECT * FROM orders WHERE status = ? ORDER BY created_at DESC LIMIT ?');
        $stmt->bindValue(1, $status, PDO::PARAM_STR);
        $stmt->bindValue(2, $limit, PDO::PARAM_INT);
        $stmt->execute();
        return $stmt->fetchAll();
    }
    return order_list_recent($limit);
}

/** Customer: order history for their account */
function order_list_by_user(int $userId, int $limit = 100): array
{
    $stmt = db()->prepare('SELECT * FROM orders WHERE user_id = ? ORDER BY created_at DESC LIMIT ?');
    $stmt->bindValue(1, $userId, PDO::PARAM_INT);
    $stmt->bindValue(2, $limit, PDO::PARAM_INT);
    $stmt->execute();
    return $stmt->fetchAll();
}

const ORDER_STATUSES = ['pending', 'processing', 'shipped', 'completed', 'cancelled'];

/** Admin: update order status, write to the tracking history log, and notify the customer */
function order_update_status(int $orderId, string $status, string $note = '', ?string $trackingNumber = null): bool
{
    if (!in_array($status, ORDER_STATUSES, true)) {
        return false;
    }
    $db = db();
    $sql = 'UPDATE orders SET status = ?';
    $params = [$status];
    if ($trackingNumber !== null) {
        $sql .= ', tracking_number = ?';
        $params[] = $trackingNumber;
    }
    $sql .= ' WHERE id = ?';
    $params[] = $orderId;
    $db->prepare($sql)->execute($params);

    $db->prepare('INSERT INTO order_status_log (order_id, status, note) VALUES (?, ?, ?)')
       ->execute([$orderId, $status, $note ?: null]);

    $order = order_find($orderId);
    if ($order && !empty($order['user_id'])) {
        require_once __DIR__ . '/notification_service.php';
        $label = ucfirst($status);
        notification_notify_customer(
            (int) $order['user_id'],
            'Order #' . str_pad((string) $orderId, 6, '0', STR_PAD_LEFT) . ' — ' . $label,
            'Your order status changed to "' . $label . '".' . ($note ? ' Note: ' . $note : '') .
                ($trackingNumber ? ' Tracking #: ' . $trackingNumber : '')
        );
    }
    return true;
}

/** Stores the PayMongo Checkout Session id against the order so the webhook can be traced back. */
function order_set_checkout_session(int $orderId, string $sessionId): void
{
    db()->prepare('UPDATE orders SET checkout_session_id = ? WHERE id = ?')->execute([$sessionId, $orderId]);
}

/** Marks an order's payment as paid/failed once PayMongo's webhook confirms it. Idempotent-safe: callers should check the current value first if they care about double-processing. */
function order_set_payment_status(int $orderId, string $paymentStatus): void
{
    if (!in_array($paymentStatus, ['unpaid', 'paid', 'failed'], true)) {
        return;
    }
    db()->prepare('UPDATE orders SET payment_status = ? WHERE id = ?')->execute([$paymentStatus, $orderId]);
}

function order_status_history(int $orderId): array
{
    $stmt = db()->prepare('SELECT * FROM order_status_log WHERE order_id = ? ORDER BY created_at ASC');
    $stmt->execute([$orderId]);
    return $stmt->fetchAll();
}

function order_set_admin_notes(int $orderId, string $notes): void
{
    db()->prepare('UPDATE orders SET admin_notes = ? WHERE id = ?')->execute([$notes, $orderId]);
}

/** Sales & Analytics: revenue + order counts, grouped by day, over the last N days */
function order_sales_by_day(int $days = 30): array
{
    $stmt = db()->prepare(
        "SELECT DATE(created_at) AS day, COUNT(*) AS orders_count, SUM(total_amount) AS revenue
         FROM orders WHERE status <> 'cancelled' AND created_at >= (NOW() - INTERVAL ? DAY)
         GROUP BY DATE(created_at) ORDER BY day ASC"
    );
    $stmt->bindValue(1, $days, PDO::PARAM_INT);
    $stmt->execute();
    return $stmt->fetchAll();
}

/** Sales & Analytics: best-selling products by units sold / revenue */
function order_top_products(int $limit = 10): array
{
    $stmt = db()->prepare(
        "SELECT oi.product_name, SUM(oi.quantity) AS units_sold, SUM(oi.subtotal) AS revenue
         FROM order_items oi JOIN orders o ON o.id = oi.order_id
         WHERE o.status <> 'cancelled'
         GROUP BY oi.product_name ORDER BY units_sold DESC LIMIT ?"
    );
    $stmt->bindValue(1, $limit, PDO::PARAM_INT);
    $stmt->execute();
    return $stmt->fetchAll();
}

/** Sales & Analytics: totals for the dashboard/reports summary cards */
function order_sales_summary(): array
{
    $row = db()->query(
        "SELECT COUNT(*) AS total_orders,
                COALESCE(SUM(CASE WHEN status <> 'cancelled' THEN total_amount ELSE 0 END),0) AS total_revenue,
                COALESCE(AVG(CASE WHEN status <> 'cancelled' THEN total_amount END),0) AS avg_order_value,
                SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) AS pending_count,
                SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_count
         FROM orders"
    )->fetch();
    return $row ?: [];
}

/** Customer insights: top customers by spend */
function order_top_customers(int $limit = 10): array
{
    $stmt = db()->prepare(
        "SELECT customer_name, customer_email, COUNT(*) AS orders_count, SUM(total_amount) AS total_spent
         FROM orders WHERE status <> 'cancelled'
         GROUP BY customer_email, customer_name
         ORDER BY total_spent DESC LIMIT ?"
    );
    $stmt->bindValue(1, $limit, PDO::PARAM_INT);
    $stmt->execute();
    return $stmt->fetchAll();
}

/**
 * The "we've got your order" email. Called once, straight after order_create()
 * commits — see the note there about why failures are swallowed.
 *
 * Deliberately does not claim payment has been received: a GCash or Card order
 * is still unpaid at this point and only PayMongo's webhook can say otherwise.
 */
function order_send_confirmation_email(
    int $orderId,
    array $customer,
    array $lines,
    float $total
): void {
    require_once __DIR__ . '/mail_service.php';
    require_once __DIR__ . '/settings_service.php';

    $email = trim((string) ($customer['email'] ?? ''));
    if ($email === '') {
        return;
    }

    $reference = '#' . str_pad((string) $orderId, 6, '0', STR_PAD_LEFT);
    $payment   = strtoupper((string) ($customer['payment_method'] ?? 'COD'));
    $shipping  = settings_shipping_for($total);

    $rows = '';
    foreach ($lines as $line) {
        $label = htmlspecialchars($line['name'])
            . ($line['size'] !== '' ? ' <span style="color:#8A8578;">(US ' . htmlspecialchars($line['size']) . ')</span>' : '')
            . ' &times; ' . (int) $line['qty'];
        $rows .= '<tr>'
            . '<td style="padding:6px 0;border-bottom:1px solid #EDEAE3;">' . $label . '</td>'
            . '<td style="padding:6px 0;border-bottom:1px solid #EDEAE3;text-align:right;white-space:nowrap;">₱'
            . number_format($line['price'] * $line['qty'], 2) . '</td>'
            . '</tr>';
    }

    $note = ($payment === 'COD')
        ? 'Pay in cash when your order arrives.'
        : 'We are confirming your ' . ($payment === 'GCASH' ? 'GCash' : 'card')
          . ' payment with PayMongo. Your order updates automatically once it clears.';

    mail_send(
        $email,
        'Your SoleCraftPH order ' . $reference,
        '<h1 style="font-size:22px;margin:0 0 12px;">Thanks, we have your order</h1>'
        . '<p style="margin:0 0 4px;">Order <strong>' . $reference . '</strong></p>'
        . '<p style="margin:0 0 20px;color:#8A8578;">' . htmlspecialchars($note) . '</p>'
        . '<table style="width:100%;border-collapse:collapse;font-size:14px;">' . $rows
        . '<tr><td style="padding:6px 0;">Shipping</td>'
        . '<td style="padding:6px 0;text-align:right;">'
        . ($shipping == 0 ? 'Free' : '₱' . number_format($shipping, 2)) . '</td></tr>'
        . '<tr><td style="padding:10px 0 0;font-weight:600;">Total</td>'
        . '<td style="padding:10px 0 0;text-align:right;font-weight:600;">₱'
        . number_format($total + $shipping, 2) . '</td></tr>'
        . '</table>'
        . '<p style="margin:20px 0 0;">Delivering to<br><span style="color:#8A8578;">'
        . nl2br(htmlspecialchars((string) ($customer['address'] ?? ''))) . '</span></p>'
        . mail_button('View your order', mail_site_url() . '/order_detail.php?id=' . $orderId)
    );
}
