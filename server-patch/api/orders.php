<?php
/**
 * Shared Order API
 * GET  /api/orders.php?id=1  -> fetch a single order + items
 * POST /api/orders.php       -> create an order
 * POST /api/orders.php?action=cancel -> customer cancels a pending order ({id})
 *      body: { "customer": {name,email,phone,address,payment_method},
 *               "items": { "<product_id>|<size>": {"product_id":1,"size":"9","qty":1}, ... } }
 *
 * A GCASH or CARD order comes back with a non-empty "checkout_url" — the same
 * PayMongo Hosted Checkout page the website redirects to. The app opens it in
 * the browser; the order stays payment_status='unpaid' until PayMongo's webhook
 * (/webhook/paymongo.php) confirms it, exactly as on the web. COD orders come
 * back with an empty "checkout_url" and nothing more to do.
 */
require_once __DIR__ . '/../config/app.php';
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/order_service.php';
require_once __DIR__ . '/../includes/cart.php';
require_once __DIR__ . '/../includes/settings_service.php';

/* ---------------------------------------------------------------------------
 * CORS + JSON headers. Lets the mobile app and browser-based clients
 * (FlutterFlow web preview, etc.) call this endpoint cross-origin.
 * ------------------------------------------------------------------------- */
require_once __DIR__ . '/../includes/cors.php';
api_cors_origin();
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204); // preflight — no body
    exit;
}

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    $id = (int) ($_GET['id'] ?? 0);

    // An order row carries the customer's name, email, phone and delivery
    // address, and order ids are sequential — so this must never answer on the
    // id alone. The website supplies a session; the app supplies a bearer token.
    $viewerId = $_SESSION['user_id'] ?? auth_user_id_from_bearer_token();
    if ($viewerId === null) {
        http_response_code(401);
        echo json_encode(['error' => 'Valid Authorization Bearer token required.']);
        exit;
    }

    $viewer  = user_find((int) $viewerId);
    $isAdmin = $viewer !== null && ($viewer['role'] ?? '') === 'admin';
    $order   = order_find($id);

    // 404 rather than 403 for someone else's order: a 403 confirms the order
    // exists, which is half of what we are trying not to leak.
    if (!$order || (!$isAdmin && (int) ($order['user_id'] ?? 0) !== (int) $viewerId)) {
        http_response_code(404);
        echo json_encode(['error' => 'Order not found']);
        exit;
    }

    // The tracking history the website shows on order_detail.php. Cheap enough
    // to always include — an order has a handful of status rows, not hundreds.
    $order['status_history'] = order_status_history($id);

    echo json_encode($order);
    exit;
}

/* ---------------------------------------------------------------------------
 * POST /api/orders.php?action=cancel  body: {"id": 56}
 *
 * The customer cancelling their own pending order from the app. Bearer token
 * only — no session — so a page on another site cannot fire it through a
 * signed-in visitor's cookie. Answers 200 with {ok, message, order} either
 * way: the app can only read the body of a successful call, and a refusal
 * ("already being prepared") is something to show, not a transport error.
 * ------------------------------------------------------------------------- */
if ($method === 'POST' && ($_GET['action'] ?? '') === 'cancel') {
    $viewerId = auth_user_id_from_bearer_token();
    $input    = json_decode(file_get_contents('php://input') ?: '', true);
    $id       = (int) (is_array($input) ? ($input['id'] ?? 0) : 0);

    $error = $viewerId === null
        ? 'Please sign in again.'
        : order_cancel_by_customer($id, (int) $viewerId);

    $order = $error === null ? order_find($id) : null;
    if ($order !== null) {
        $order['status_history'] = order_status_history($id);
    }

    echo json_encode([
        'ok'      => $error === null,
        'message' => $error ?? 'Order cancelled. The shoes are back in stock.',
        'order'   => $order,
    ]);
    exit;
}

if ($method === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input || empty($input['customer']) || empty($input['items'])) {
        http_response_code(422);
        echo json_encode(['error' => 'Missing customer or items']);
        exit;
    }

    $customer = $input['customer'];
    // Website checkout supplies the session; the mobile app supplies a bearer
    // token. Guests have neither, and still check out fine with a null user_id.
    $customer['user_id'] = $_SESSION['user_id'] ?? auth_user_id_from_bearer_token();

    foreach (['name', 'email', 'phone', 'address'] as $field) {
        if (empty($customer[$field])) {
            http_response_code(422);
            echo json_encode(['error' => "Missing customer field: $field"]);
            exit;
        }
    }

    try {
        $orderId = order_create($customer, $input['items']);
        order_update_status($orderId, 'pending', 'Order placed from the mobile app.');

        // GCASH / CARD go through PayMongo Hosted Checkout — the same service
        // call the website's checkout.php makes, so both clients produce the
        // same kind of session and the one webhook settles either of them.
        $payment     = strtoupper((string) ($customer['payment_method'] ?? 'COD'));
        $checkoutUrl = '';

        if ($payment === 'GCASH' || $payment === 'CARD') {
            require_once __DIR__ . '/../includes/paymongo_service.php';

            $order     = order_find($orderId);
            $lineItems = [];
            foreach ($order['items'] as $row) {
                $lineItems[] = [
                    // Size belongs on the PayMongo receipt too — it is the only
                    // thing distinguishing two otherwise identical lines.
                    'name'  => $row['product_name'] . (!empty($row['size']) ? ' (US ' . $row['size'] . ')' : ''),
                    'price' => (float) $row['unit_price'],
                    'qty'   => (int) $row['quantity'],
                ];
            }

            $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
            $origin = $scheme . '://' . $_SERVER['HTTP_HOST'];

            try {
                $session = paymongo_create_checkout_session(
                    $orderId,
                    $lineItems,
                    settings_shipping_for((float) $order['total_amount']),
                    [strtolower($payment)],
                    // A phone-sized landing page rather than the full desktop
                    // storefront — this renders inside the app's payment WebView.
                    $origin . BASE_PATH . '/payment_return.php?id=' . $orderId,
                    $origin . BASE_PATH . '/payment_return.php?id=' . $orderId . '&state=cancelled'
                );
                order_set_checkout_session($orderId, $session['session_id']);
                $checkoutUrl = $session['checkout_url'];
            } catch (Throwable $paymentError) {
                // Same call the website makes: cancel rather than leave an order
                // that can never be paid, and keep the cart so they can retry.
                order_update_status($orderId, 'cancelled', 'Could not start PayMongo checkout: ' . $paymentError->getMessage());
                http_response_code(502);
                echo json_encode([
                    'error' => 'Could not start the payment step. Please try again, or choose Cash on Delivery.',
                ]);
                exit;
            }
        }

        // The order is placed, so the shared cart is spent. Doing it here means
        // the app never has to remember to, and the website shows an empty cart
        // the moment a phone order goes through.
        if (!empty($customer['user_id'])) {
            cart_clear();
        }
        http_response_code(201);
        echo json_encode([
            'id'           => $orderId,
            'message'      => 'Order created',
            'checkout_url' => $checkoutUrl,
        ]);
    } catch (Throwable $e) {
        http_response_code(400);
        echo json_encode(['error' => $e->getMessage()]);
    }
    exit;
}

http_response_code(405);
echo json_encode(['error' => 'Method not allowed']);
