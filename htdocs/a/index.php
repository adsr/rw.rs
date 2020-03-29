<?php

require 'rwrs.php';
require 'crawdb.php';

define('ARWRS_BASE_URL', 'http://a.rw.rs');
define('ARWRS_HOST', 'a.rw.rs');
define('ARWRS_MAX_PATH_LEN', 6);
define('ARWRS_MAX_URL_LEN', 2048);
define('ARWRS_DB_PREFIX', rwrs_config_require('arwrs_db_prefix'));
define('ARWRS_CRAWDB_ERR_SET_ALREADY_EXISTS', -24);
define('ARWRS_RECAPTCHA_SITEKEY', '6LekGeQUAAAAAEbgS2b8I7aC_XwJ8HsUeHYZH-vW');

function arwrs_main() {
    // Switch request by URI and method
    // Requires the following line in Apache config:
    //
    //   AliasMatch "^(.*)$" "/usr/httpd/htdocs/a/index.php"
    //
    $req_uri = $_SERVER['REQUEST_URI'] ?? null;
    $req_method = $_SERVER['REQUEST_METHOD'] ?? null;
    $req_parts = parse_url($req_uri);
    $req_path = $req_parts['path'] ?? null;
    if ($req_method === 'GET' && $req_path === '/') {
        return arwrs_handle_home();
    } else if ($req_method === 'POST' && $req_path === '/shorten') {
        return arwrs_handle_shorten();
    } else if ($req_method === 'GET') {
        return arwrs_handle_redirect(trim($req_path, '/'));
    }
    return arwrs_respond(404, '404', ['Content-Type: text/plain']);
}

function arwrs_handle_home() {
    // Render home page and form
    $html = arwrs_render_html(
        '<p>URL shortener</p>' . "\n" .
        '<script src="https://www.google.com/recaptcha/api.js" async defer></script>' . "\n" .
        '<form action="/shorten" method="post">' . "\n" .
        sprintf('<p><input type="text" name="url"  size="64" maxlength="%d" placeholder="URL"> (<= %d chars)<p>', ARWRS_MAX_URL_LEN, ARWRS_MAX_URL_LEN) . "\n" .
        sprintf('<p><input type="text" name="path" size="24" maxlength="%d" placeholder="path"> (<= %d chars, A-Z, a-z, 0-9, dashes)</p>', ARWRS_MAX_PATH_LEN, ARWRS_MAX_PATH_LEN) . "\n" .
        sprintf('<div class="g-recaptcha" data-sitekey="%s"></div>', ARWRS_RECAPTCHA_SITEKEY) .
        '<p><input type="submit"></p>' . "\n" .
        '</form>' . "\n"
    );
    return arwrs_respond(200, $html, ['Content-Type: text/html']);
}

function arwrs_handle_shorten() {
    // Check url
    $url = $_POST['url'] ?? null;
    $url_scheme = parse_url($url, PHP_URL_SCHEME);
    $url_host = parse_url($url, PHP_URL_HOST);
    if (strlen($url) > ARWRS_MAX_URL_LEN) {
        return arwrs_respond(400, sprintf('URL should be <= %d chars', ARWRS_MAX_URL_LEN), ['Content-Type: text/plain']);
    }
    if ($url_scheme !== 'http' && $url_scheme !== 'https') {
        return arwrs_respond(400, 'Does not look like an HTTP URL', ['Content-Type: text/plain']);
    }
    if (strlen($url_host) < 1) {
        return arwrs_respond(400, 'Could not parse URL host', ['Content-Type: text/plain']);
    }
    if (strtolower($url_host) === ARWRS_HOST) {
        return arwrs_respond(400, 'That would not be productive', ['Content-Type: text/plain']);
    }

    // Check path
    $path = trim($_POST['path'] ?? '');
    if (strlen($path) < 1) {
        return arwrs_respond(400, 'Empty path', ['Content-Type: text/plain']);
    }
    if (strlen($path) > ARWRS_MAX_PATH_LEN) {
        return arwrs_respond(400, sprintf('Path should be <= %d chars', ARWRS_MAX_PATH_LEN), ['Content-Type: text/plain']);
    }
    if (preg_match('/[^A-Za-z0-9-]/', $path)) {
        return arwrs_respond(400, 'Path should only consist of A-Z, a-z, 0-9, dashes', ['Content-Type: text/plain']);
    }

    // Check captcha
    $captcha_response = $_POST['g-recaptcha-response'] ?? null;
    if (!$captcha_response) {
        return arwrs_respond(400, 'Missing captcha', ['Content-Type: text/plain']);
    } else if (!arwrs_valid_captcha($captcha_response)) {
        return arwrs_respond(400, 'Invalid captcha', ['Content-Type: text/plain']);
    }

    // Shorten
    $error_code = 500;
    $error_msg = null;
    $short_url = arwrs_insert($url, $path, $error_code, $error_msg);
    if (!$short_url) {
        return arwrs_respond($error_code, "Failed to shorten URL $url: $error_msg", ['Content-Type: text/plain']);
    }
    $html = arwrs_render_html(sprintf(
        '<p>Shortened URL <b>%s</b> to:</p>' . "\n" .
        '<p><input type="text" value="%s" size="64" onclick="this.select(); document.execCommand(\'copy\');"> (Click to copy)</p>' . "\n",
        htmlspecialchars($url),
        htmlspecialchars($short_url)
    ));
    return arwrs_respond(200, $html, ['Content-Type: text/html']);
}

function arwrs_valid_captcha($captcha_response) {
    // Verify captcha
    // Skip for localhost
    if (in_array($_SERVER['REMOTE_ADDR'] ?? '', ['::1', '127.0.0.1'])) {
        return true;
    }
    $context = stream_context_create([ 'http' => [
        'method' => 'POST',
        'content' => http_build_query([
            'secret' => $_SERVER['RECAPTCHA_SECRET'] ?? '',
            'response' => $captcha_response,
        ]),
        'timeout' => 5,
    ]]);
    $json = @file_get_contents(
        'https://www.google.com/recaptcha/api/siteverify',
        $use_include_path = false,
        $context
    );
    $res = @json_decode($json, true);
    return !empty($res['success']);
}

function arwrs_handle_redirect($path) {
    // Lookup entry and redirect or error
    $error_code = 0;
    $error_msg = null;
    $url = arwrs_lookup($path, $error_code, $error_msg);
    if (!$url) {
        return arwrs_respond($error_code, $error_msg, ['Content-Type: text/plain']);
    }
    return arwrs_respond(301, '', ["Location: $url"]);
}

function arwrs_insert($url, $path, &$error_code, &$error_msg) {
    // Write entry
    return arwrs_with_craw(function($crawh, &$error_code, &$error_msg) use ($url, $path) {
        $rv = crawdb_set($crawh, $path, $url);
        if ($rv === ARWRS_CRAWDB_ERR_SET_ALREADY_EXISTS) {
            list($error_code, $error_msg) = [400, 'Path already exists'];
            return;
        } else if ($rv !== 0) {
            list($error_code, $error_msg) = [500, 'crawdb_set'];
            return;
        }
        return sprintf('http://a.rw.rs/%s', $path);
    }, $error_code, $error_msg);
}

function arwrs_lookup($path, &$error_code, &$error_msg) {
    // Lookup entry
    return arwrs_with_craw(function($crawh, &$error_code, &$error_msg) use ($path) {
        $url = crawdb_get($crawh, $path);
        if (!$url) {
            $rv = crawdb_last_error($crawh);
            if ($rv === 0) {
                list($error_code, $error_msg) = [404, '404'];
                return;
            } else {
                list($error_code, $error_msg) = [500, 'crawdb_get'];
                return;
            }
        }
        return $url;
    }, $error_code, $error_msg);
}

function arwrs_with_craw($fn, &$error_code, &$error_msg) {
    // Ensure db dir exists
    $db_dir = dirname(ARWRS_DB_PREFIX);
    if (!is_dir($db_dir)) {
        if (!mkdir($db_dir, 0777, true)) {
            list($error_code, $error_msg) = [500, 'mkdir'];
            return;
        }
    }

    // Ensure db files exist and open
    $db_idx = ARWRS_DB_PREFIX . '.idx';
    $db_dat = ARWRS_DB_PREFIX . '.dat';
    $errno = 0;
    if (is_file($db_idx)) {
        $crawh = crawdb_open($db_idx, $db_dat, $errno);
    } else {
        $crawh = crawdb_new($db_idx, $db_dat, ARWRS_MAX_PATH_LEN, $errno);
    }
    if (!$crawh) {
        list($error_code, $error_msg) = [500, "crawdb_open ($errno)"];
        return;
    }

    // Apply fn and free db
    $rv = $fn($crawh, $error_code, $error_msg);
    crawdb_free($crawh);
    return $rv;
}

function arwrs_respond($code, $content, $headers = []) {
    // Respond and exit
    foreach ($headers as $header) {
        header($header, true);
    }
    http_response_code($code);
    echo $content . "\n";
}

function arwrs_render_html($content) {
    // Render content with header and footer
    $html_header = <<<'EOD'
        <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>a.rw.rs</title>
        </head>
        <body>
        <h1>a.rw.rs</h1>
    EOD;
    $html_footer = <<<'EOD'
        </body>
        </html>
    EOD;
    $strip = fn($s) => preg_replace('/^\s+/m', '', $s);
    return $strip($html_header) . "\n" . $content . "\n" . $strip($html_footer);
}

arwrs_main();
