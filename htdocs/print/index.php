<?php

require 'rwrs.php';
require 'crawdb.php';

function print_main() {
    // Switch request by method
    $ctx = (object)[
        'printcap_max_name_len' => rwrs_config_require('printcap_max_name_len'),
        'printcap_max_msg_len' => rwrs_config_require('printcap_max_msg_len'),
        'printcap_max_bytes_factor' => rwrs_config_require('printcap_max_bytes_factor'),
        'printcap_queue_path' => rwrs_config_require('printcap_queue_path'),
    ];
    $req_method = $_SERVER['REQUEST_METHOD'] ?? null;
    if ($req_method === 'GET') {
        return print_handle_home($ctx);
    } else if ($req_method === 'POST') {
        return print_handle_print($ctx);
    }
    return print_respond(404, '404', ['Content-Type: text/plain']);
}

function print_handle_home($ctx) {
    // Render home page and form
    $html = print_render_html(
        '<p><img src="/image" width="640" height="480" onclick="this.src=this.src" style="cursor:pointer"></p>' . "\n" .
        '<script src="https://www.google.com/recaptcha/api.js" async defer></script>' . "\n" .
        '<form action="/" method="post">' . "\n" .
        sprintf('<p><input type="text" name="msg" size="64" placeholder="message"> (<= %d chars)<p>', $ctx->printcap_max_msg_len) . "\n" .
        sprintf('<p><input type="text" name="name" size="16" placeholder="anonymous"> (<= %d chars)<p>', $ctx->printcap_max_name_len) . "\n" .
        '<p>(chars=<a href="https://i.imgur.com/rAvecgL.jpg">0x20-0xff</a>, bold=0x01, underline=0x02, invert=0x03)</p>' . "\n" .
        sprintf('<div class="g-recaptcha" data-sitekey="%s"></div>', $_SERVER['RECAPTCHA_SITEKEY'] ?? '') .
        '<p><input type="submit"></p>' . "\n" .
        '</form>' . "\n"
    );
    return print_respond(200, $html, ['Content-Type: text/html']);
}

function print_handle_print($ctx) {
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
    } else if (strlen($msg_minus_ctl) > $ctx->printcap_max_msg_len) {
        return print_respond(400, 'Message too long', ['Content-Type: text/plain']);
    } else if (strlen($msg) > $ctx->printcap_max_msg_len * $ctx->printcap_max_bytes_factor) {
        return print_respond(400, 'Message too long', ['Content-Type: text/plain']);
    }

    // Check name
    $name = $_POST['name'] ?? '';
    $name_minus_ctl = preg_replace('/[\x00-\x1f]/', '', $name);
    if (strlen($name_minus_ctl) < 1) {
        $name = 'Anonymous';
    } else if (strlen($name_minus_ctl) > $ctx->printcap_max_name_len) {
        return print_respond(400, 'Name too long', ['Content-Type: text/plain']);
    } else if (strlen($name) > $ctx->printcap_max_name_len * $ctx->printcap_max_bytes_factor) {
        return print_respond(400, 'Name too long', ['Content-Type: text/plain']);
    }

    // Queue for printing
    $payload = sprintf(
        "%d %s %s\n",
        $_SERVER['REQUEST_TIME_FLOAT'] ?? 0,
        base64_encode($name),
        base64_encode($msg)
    );
    $rv = file_put_contents($ctx->printcap_queue_path, $payload, FILE_APPEND);

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
