<?php
/**
 * Outgoing email.
 *
 * Uses PHP's built-in mail() — Hostinger routes it through their local MTA, so
 * there is nothing to install and no credentials to store. If delivery turns
 * out to be unreliable from this domain, this is the one file to swap for an
 * SMTP sender; everything else calls mail_send() and does not care how it goes.
 *
 * Every attempt is logged to mail.log one level ABOVE public_html, so a mail
 * that never arrives can be told apart from a mail that was never sent. That
 * distinction is most of the debugging.
 */
require_once __DIR__ . '/../config/app.php';

/** Where mail appears to come from. A real mailbox on the domain delivers best. */
if (!defined('MAIL_FROM')) {
    define('MAIL_FROM', 'noreply@snow-jellyfish-553645.hostingersite.com');
}
if (!defined('MAIL_FROM_NAME')) {
    define('MAIL_FROM_NAME', 'SoleCraftPH');
}

function mail_log(string $message): void
{
    @file_put_contents(
        __DIR__ . '/../../mail.log',
        gmdate('c') . ' ' . $message . PHP_EOL,
        FILE_APPEND | LOCK_EX
    );
}

/**
 * Sends one HTML email. Returns true when the MTA accepted it — which is not
 * the same as the customer receiving it, hence the log.
 */
function mail_send(string $to, string $subject, string $bodyHtml): bool
{
    if (!filter_var($to, FILTER_VALIDATE_EMAIL)) {
        mail_log('SKIPPED invalid address: ' . $to);
        return false;
    }

    $headers = [
        'MIME-Version: 1.0',
        'Content-Type: text/html; charset=UTF-8',
        'From: ' . MAIL_FROM_NAME . ' <' . MAIL_FROM . '>',
        'Reply-To: ' . MAIL_FROM,
        'X-Mailer: SoleCraftPH',
    ];

    $ok = @mail($to, $subject, mail_wrap($bodyHtml), implode("\r\n", $headers));
    mail_log(($ok ? 'SENT    ' : 'FAILED  ') . $to . ' — ' . $subject);
    return $ok;
}

/** Wraps body copy in the storefront's look, so mail matches the site. */
function mail_wrap(string $inner): string
{
    return '<!doctype html><html><body style="margin:0;padding:24px;'
        . 'background:#FAF9F6;font-family:Inter,Arial,Helvetica,sans-serif;'
        . 'color:#111111;line-height:1.6;">'
        . '<div style="max-width:520px;margin:0 auto;background:#FFFFFF;'
        . 'border:1px solid #EDEAE3;border-radius:12px;padding:28px;">'
        . '<div style="font-size:13px;letter-spacing:.16em;text-transform:uppercase;'
        . 'color:#E2412A;margin-bottom:18px;">SoleCraftPH</div>'
        . $inner
        . '</div>'
        . '<p style="max-width:520px;margin:16px auto 0;font-size:12px;color:#8A8578;'
        . 'text-align:center;">You are receiving this because you have an account '
        . 'at SoleCraftPH.</p>'
        . '</body></html>';
}

/** A primary call-to-action button, inline-styled so mail clients keep it. */
function mail_button(string $label, string $url): string
{
    return '<p style="margin:24px 0;"><a href="' . htmlspecialchars($url) . '" '
        . 'style="display:inline-block;background:#111111;color:#FFFFFF;'
        . 'text-decoration:none;padding:14px 22px;border-radius:12px;'
        . 'font-weight:600;">' . htmlspecialchars($label) . '</a></p>';
}

/** The site's own base URL, for links inside emails. */
function mail_site_url(): string
{
    $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $host   = $_SERVER['HTTP_HOST'] ?? 'snow-jellyfish-553645.hostingersite.com';
    return $scheme . '://' . $host . (defined('BASE_PATH') ? BASE_PATH : '');
}
