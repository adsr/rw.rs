<?php

require 'rwrs.php';
require 'crawdb.php';

define('PRINT_MAX_MSG_LEN', 42);
define('PRINT_MAX_NAME_LEN', 16);
define('PRINT_QUEUE_PATH', '/var/rw.rs/apache/print_queue.txt');

function print_main() {
    // Switch request by method
    $req_method = $_SERVER['REQUEST_METHOD'] ?? null;
    if ($req_method === 'GET') {
        return print_handle_home();
    } else if ($req_method === 'POST') {
        return print_handle_print();
    }
    return print_respond(404, '404', ['Content-Type: text/plain']);
}

function print_handle_home() {
    // Render home page and form
    $html = print_render_html(
        '<p><img src="/image" width="640" height="480"></p>' . "\n" .
        '<script src="https://www.google.com/recaptcha/api.js" async defer></script>' . "\n" .
        '<form action="/" method="post">' . "\n" .
        sprintf('<p><input type="text" name="msg" size="64" placeholder="message"> (<= %d chars)<p>', PRINT_MAX_MSG_LEN) . "\n" .
        sprintf('<p><input type="text" name="name" size="16" placeholder="anonymous"> (<= %d chars)<p>', PRINT_MAX_NAME_LEN) . "\n" .
        '<p>(chars=<a href="https://i.imgur.com/rAvecgL.jpg">0x20-0xff</a>, bold=0x01, underline=0x02, invert=0x03)</p>' . "\n" .
        sprintf('<div class="g-recaptcha" data-sitekey="%s"></div>', $_SERVER['RECAPTCHA_SITEKEY'] ?? '') .
        '<p><input type="submit"></p>' . "\n" .
        '</form>' . "\n"
    );
    return print_respond(200, $html, ['Content-Type: text/html']);
}

function print_handle_print() {
    // Check captcha
    $captcha_response = $_POST['g-recaptcha-response'] ?? null;
    if (!$captcha_response) {
        return print_respond(400, 'Missing captcha', ['Content-Type: text/plain']);
    } else if (!rwrs_valid_captcha($captcha_response)) {
        return print_respond(400, 'Invalid captcha', ['Content-Type: text/plain']);
    }

    // Check msg
    $msg = $_POST['msg'] ?? '';
    $msg_minus_ctl = preg_replace('/[\x00-\x1f]/', '', $msg);
    if (strlen($msg_minus_ctl) < 1) {
        return print_respond(400, 'Empty message', ['Content-Type: text/plain']);
    } else if (strlen($msg_minus_ctl) > PRINT_MAX_MSG_LEN) {
        return print_respond(400, 'Message too long', ['Content-Type: text/plain']);
    } else if (strlen($msg) > PRINT_MAX_MSG_LEN * 3) {
        return print_respond(400, 'Message too long', ['Content-Type: text/plain']);
    }

    // Check name
    $name = $_POST['name'] ?? '';
    $name_minus_ctl = preg_replace('/[\x00-\x1f]/', '', $name);
    if (strlen($name_minus_ctl) < 1) {
        $name = 'Anonymous';
    } else if (strlen($name_minus_ctl) > PRINT_MAX_NAME_LEN) {
        return print_respond(400, 'Name too long', ['Content-Type: text/plain']);
    } else if (strlen($name) > PRINT_MAX_NAME_LEN * 3) {
        return print_respond(400, 'Name too long', ['Content-Type: text/plain']);
    }

    // Queue for printing
    $payload = sprintf(
        "%d %s %s\n",
        $_SERVER['REQUEST_TIME'] ?? 0,
        base64_encode($name),
        base64_encode($msg)
    );
    $rv = file_put_contents(PRINT_QUEUE_PATH, $payload, FILE_APPEND);

    // Respond
    if ($rv === false) {
        return print_respond(500, 'Could not queue', ['Content-Type: text/plain']);
    }
    return print_respond(200, 'Queued', ['Content-Type: text/plain']);
}

function print_respond($code, $content, $headers = []) {
    // Respond and exit
    foreach ($headers as $header) {
        header($header, true);
    }
    http_response_code($code);
    echo $content . "\n";
}

function print_render_html($content) {
    // Render content with header and footer
    $html_header = <<<'EOD'
        <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>print.rw.rs</title>
        </head>
        <body>
        <h1>print.rw.rs</h1>
    EOD;
    $html_footer = <<<'EOD'
        </body>
        </html>
    EOD;
    $strip = fn($s) => preg_replace('/^\s+/m', '', $s);
    return $strip($html_header) . "\n" . $content . "\n" . $strip($html_footer);
}

print_main();
