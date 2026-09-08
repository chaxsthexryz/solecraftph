<?php
require __DIR__ . '/bootstrap.php';
require_method('POST');

$in = body_input();

// Optional auth: if a valid token is present, the order is tied to that user.
$user   = current_user($pdo);
$userId = $user ? (int) $user['id'] : null;

// --- Shipping details ----------------------------------------------------
$name    = input_str($in, 'customer_name');
$email   = strtolower(input_str($in, 'customer_email'));
$phone   = input_str($in, 'customer_phone');
$address = input_str($in, 'customer_address');
$payment = strtoupper(input_str($in, 'payment_method', 'COD'));

// Fall back to the account's stored details when logged in.
if ($user) {
    if ($name === '')    { $name = (string) ($user['full_name'] ?? ''); }
    if ($email === '')   { $email = (string) ($user['email'] ?? ''); }
    if ($phone === '')   { $phone = (string) ($user['phone'] ?? ''); }
    if ($address === '') { $address = (string) ($user['address'] ?? ''); }
}

if ($name === '' || $email === '' || $phone === '' || $address === '') {
    json_error('Full name, email, phone and address are required.', 400);
}
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    json_error('Please provide a valid email address.', 400);
}
if (!in_array($payment, ['COD', 'GCASH', 'CARD'], true)) {
    json_error('Invalid payment method.', 400);
}

// --- Cart ---------------------------------------------------------------
$cart = $in['cart'] ?? ($in['items'] ?? null);
// Mobile clients may send the cart as a JSON-encoded string.
if (is_string($cart)) {
    $decoded = json_decode($cart, true);
    if (is_array($decoded)) {
        $cart = $decoded;
    }
}
if (!is_array($cart) || count($cart) === 0) {
    json_error('Your cart is empty.', 400);
}

// Collapse duplicate product ids and validate quantities.
$wanted = [];   // product_id => quantity
foreach ($cart as $line) {
    if (!is_array($line)) {
        continue;
    }
    $pid = (int) ($line['product_id'] ?? ($line['productId'] ?? 0));
    $qty = (int) ($line['quantity'] ?? ($line['qty'] ?? 0));
    if ($pid <= 0 || $qty <= 0) {
        json_error('Each cart item needs a valid product_id and quantity.', 400);
    }
    $wanted[$pid] = ($wanted[$pid] ?? 0) + $qty;
}
if (count($wanted) === 0) {
    json_error('Your cart is empty.', 400);
}

// --- Transaction --------------------------------------------------------
try {
    $pdo->beginTransaction();

    // Lock the product rows we intend to sell.
    $ids          = array_keys($wanted);
    $placeholders = implode(',', array_fill(0, count($ids), '?'));
    $stmt = $pdo->prepare(
        "SELECT id, name, price, sale_price, stock, is_active
           FROM products
          WHERE id IN ($placeholders)
          FOR UPDATE"
    );
    $stmt->execute($ids);
    $found = [];
    foreach ($stmt->fetchAll() as $row) {
        $found[(int) $row['id']] = $row;
    }

    $items = [];
    $total = 0.0;

    foreach ($wanted as $pid => $qty) {
        if (!isset($found[$pid]) || (int) $found[$pid]['is_active'] !== 1) {
            $pdo->rollBack();
            json_error("Product #$pid is no longer available.", 400);
        }
        $p     = $found[$pid];
        $stock = (int) $p['stock'];
        if ($stock < $qty) {
            $pdo->rollBack();
            json_error("Not enough stock for \"{$p['name']}\" (only $stock left).", 409);
        }
        $unit     = $p['sale_price'] !== null ? (float) $p['sale_price'] : (float) $p['price'];
        $subtotal = round($unit * $qty, 2);
        $total   += $subtotal;

        $items[] = [
            'product_id'   => $pid,
            'product_name' => $p['name'],
            'unit_price'   => $unit,
            'quantity'     => $qty,
            'subtotal'     => $subtotal,
        ];
    }
    $total = round($total, 2);

    // Insert the order.
    $orderStmt = $pdo->prepare(
        'INSERT INTO orders
            (user_id, customer_name, customer_email, customer_phone,
             customer_address, payment_method, total_amount, status)
         VALUES
            (:uid, :name, :email, :phone, :address, :payment, :total, "pending")'
    );
    $orderStmt->execute([
        ':uid'     => $userId,
        ':name'    => $name,
        ':email'   => $email,
        ':phone'   => $phone,
        ':address' => $address,
        ':payment' => $payment,
        ':total'   => $total,
    ]);
    $orderId = (int) $pdo->lastInsertId();

    // Insert order items + decrement stock.
    $itemStmt = $pdo->prepare(
        'INSERT INTO order_items
            (order_id, product_id, product_name, unit_price, quantity, subtotal)
         VALUES (:oid, :pid, :pname, :price, :qty, :subtotal)'
    );
    $stockStmt = $pdo->prepare('UPDATE products SET stock = stock - :qty WHERE id = :pid');

    foreach ($items as $it) {
        $itemStmt->execute([
            ':oid'      => $orderId,
            ':pid'      => $it['product_id'],
            ':pname'    => $it['product_name'],
            ':price'    => $it['unit_price'],
            ':qty'      => $it['quantity'],
            ':subtotal' => $it['subtotal'],
        ]);
        $stockStmt->execute([':qty' => $it['quantity'], ':pid' => $it['product_id']]);
    }

    // Initial status-log row.
    $logStmt = $pdo->prepare(
        'INSERT INTO order_status_log (order_id, status, note)
         VALUES (:oid, "pending", "Order placed via mobile app.")'
    );
    $logStmt->execute([':oid' => $orderId]);

    $pdo->commit();
} catch (PDOException $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log('SoleCraftPH checkout error: ' . $e->getMessage());
    json_error('Could not place your order. Please try again.', 500);
}

json_ok([
    'order_id'       => $orderId,
    'total_amount'   => $total,
    'status'         => 'pending',
    'payment_method' => $payment,
    'items'          => $items,
], 'Order placed successfully.', 201);
