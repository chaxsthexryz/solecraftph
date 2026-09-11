<?php
/**
 * PayMongo Hosted Checkout (v2) — one API call gets a checkout_url that
 * handles GCash and Card entirely on PayMongo's own page, so this site
 * never touches card numbers or GCash credentials directly.
 */
require_once __DIR__ . '/../config/paymongo.php';

/**
 * @param int    $orderId       Used as the reference_number so the webhook
 *                               can look the order back up.
 * @param array  $cartItems     ['product_id' => ['name'=>.., 'price'=>.., 'qty'=>..], ...]
 * @param float  $shippingFee
 * @param array  $paymentMethodTypes  e.g. ['gcash'] or ['card']
 * @param string $successUrl
 * @param string $cancelUrl
 * @return array ['checkout_url' => string, 'session_id' => string]
 * @throws RuntimeException on any API or network failure
 */
function paymongo_create_checkout_session(
    int $orderId,
    array $cartItems,
    float $shippingFee,
    array $paymentMethodTypes,
    string $successUrl,
    string $cancelUrl
): array {
    if (PAYMONGO_SECRET_KEY === '') {
        throw new RuntimeException('PayMongo is not configured (PAYMONGO_SECRET_KEY is empty).');
    }

    $lineItems = [];
    foreach ($cartItems as $item) {
        $lineItems[] = [
            'name'     => $item['name'],
            // PayMongo amounts are in centavos (smallest currency unit).
            'amount'   => (int) round($item['price'] * 100),
            'currency' => 'PHP',
            'quantity' => (int) $item['qty'],
        ];
    }
    if ($shippingFee > 0) {
        $lineItems[] = [
            'name'     => 'Shipping',
            'amount'   => (int) round($shippingFee * 100),
            'currency' => 'PHP',
            'quantity' => 1,
        ];
    }

    $payload = [
        'data' => [
            'attributes' => [
                'line_items'           => $lineItems,
                'payment_method_types' => $paymentMethodTypes,
                'reference_number'     => (string) $orderId,
                'success_url'          => $successUrl,
                'cancel_url'           => $cancelUrl,
            ],
        ],
    ];

    $ch = curl_init('https://api.paymongo.com/v2/checkout_sessions');
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST           => true,
        CURLOPT_POSTFIELDS     => json_encode($payload),
        CURLOPT_HTTPHEADER     => ['Content-Type: application/json'],
        CURLOPT_USERPWD        => PAYMONGO_SECRET_KEY . ':',
        CURLOPT_CONNECTTIMEOUT => 8,  // bounds the connect/DNS phase specifically
        CURLOPT_TIMEOUT        => 15, // bounds the whole request
        CURLOPT_NOSIGNAL       => true, // required for the above timeouts to be honored under PHP-FPM
    ]);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlError = curl_error($ch);
    curl_close($ch);

    if ($response === false) {
        throw new RuntimeException('Could not reach PayMongo: ' . $curlError);
    }

    $decoded = json_decode($response, true);
    if ($httpCode >= 300 || !isset($decoded['data']['attributes']['checkout_url'])) {
        $message = $decoded['errors'][0]['detail'] ?? ('Unexpected PayMongo response (HTTP ' . $httpCode . ').');
        throw new RuntimeException($message);
    }

    return [
        'checkout_url' => $decoded['data']['attributes']['checkout_url'],
        'session_id'   => $decoded['data']['id'],
    ];
}

/**
 * Verifies the Paymongo-Signature header on an incoming webhook request.
 * Header shape: t=<timestamp>,te=<test-mode signature>,li=<live-mode signature>
 *
 * @param string $rawPayload  The exact, unparsed request body (php://input) —
 *                              re-encoding the JSON before verifying breaks the check.
 */
function paymongo_verify_webhook_signature(string $rawPayload, string $signatureHeader, bool $testMode = true): bool
{
    if (PAYMONGO_WEBHOOK_SECRET === '' || $signatureHeader === '') {
        return false;
    }

    $parts = [];
    foreach (explode(',', $signatureHeader) as $piece) {
        [$key, $value] = array_pad(explode('=', $piece, 2), 2, null);
        if ($key !== null && $value !== null) {
            $parts[trim($key)] = trim($value);
        }
    }

    $timestamp = $parts['t'] ?? null;
    $expectedSignature = $testMode ? ($parts['te'] ?? null) : ($parts['li'] ?? null);
    if ($timestamp === null || $expectedSignature === null) {
        return false;
    }

    $computed = hash_hmac('sha256', $timestamp . '.' . $rawPayload, PAYMONGO_WEBHOOK_SECRET);
    return hash_equals($expectedSignature, $computed);
}