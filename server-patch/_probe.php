<?php
if (($_GET['t'] ?? '') !== '14a6b701fa6e61f0e482e284') { http_response_code(404); exit; }
header('Content-Type: application/json');
$out = ['openssl' => extension_loaded('openssl'), 'transports' => stream_get_transports()];
foreach ([['smtp.gmail.com', 587], ['smtp.gmail.com', 465]] as [$h, $p]) {
    $err = $errno = null;
    $t0 = microtime(true);
    $s = @stream_socket_client("tcp://$h:$p", $errno, $err, 8);
    if ($s) {
        $banner = trim((string) @fgets($s, 512));
        fclose($s);
        $out["$h:$p"] = ['ok' => true, 'ms' => (int) ((microtime(true) - $t0) * 1000), 'banner' => $banner];
    } else {
        $out["$h:$p"] = ['ok' => false, 'errno' => $errno, 'error' => $err];
    }
}
echo json_encode($out, JSON_PRETTY_PRINT);
