<?php

function main() {
    // AliasMatch "^(.*)$" "/usr/httpd/htdocs/a/index.php"
    $req_uri = $_SERVER['REQUEST_URI'] ?? null;
    $req_method = $_SERVER['REQUEST_METHOD'] ?? null;
    $req_parts = parse_url($req_uri);
    $req_path = $req_parts['path'] ?? null;
    if ($req_method === 'GET' && $req_path === '/') {
        handle_home();
    } else if ($req_method === 'POST' && $req_path === '/shorten') {
        handle_shorten();
    } else if ($req_method === 'GET') {
        handle_redirect($req_path);
    } else {
        respond(404, '404', ['Content-Type: text/plain']);
    }
}

function handle_home() {
    $html = render_html('<p>URL shortener</p>' .
        '<form method="post">' .
        '<p><input type="text" name="url" placeholder="http://"></p>' .
        '<p><input type="text" name="path" placeholder="path"></p>' .
        '<p><input type="submit"></p>' .
        '</form>');
    respond(200, $html, ['Content-Type: text/html']);
}

function handle_shorten() {
    $url = $_POST['url'] ?? null;
    $scheme = parse_url($url, PHP_URL_SCHEME);
    if ($scheme !== 'http' && $scheme !== 'https') {
        respond(400, "Could not parse URL $url", ['Content-Type: text/plain']);
    }
    $error = null;
    $short_url = shorten($url, $_POST['path'] ?? null, $error);
    if (!$short_url) {
        respond(500, "Failed to shorten URL $url: $error", ['Content-Type: text/plain']);
    }
    $html = render_html(sprintf(
        '<p>Shortened URL <b>%s</b> to:</p>' .
        '<p><input type="text" value="%s" onclick="document.execCommand(\'copy\');"></p>' .
        '<p></i>Click to copy</i></p>',
        htmlspecialchars($url),
        htmlspecialchars($short_url)
    ));
    respond(200, $html, ['Content-Type: text/html']);
}

function handle_redirect($path) {
    $url = find_link($path);
    if (!$url) {
        respond(404, '404', ['Content-Type: text/plain']);
    }
    respond(302, '', ["Location: $url"]);
}

function shorten($url, $path) {
    return 'http://a.rw.rs/stub';
}

function find_link($path) {
    return 'http://a.rw.rs/stub';
}

function respond($code, $content, $headers = []) {
    foreach ($headers as $header) {
        header($header, true);
    }
    http_response_code($code);
    echo $content;
    exit(0);
}


$html_header = <<<'EOD'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>a.rw.rs</title>
</head>
<body>
<h1>a.rw.rs</h1>
EOD;

$html_footer = <<<'EOD'
</body>
</html>
EOD;

function render_html($content) {
    global $html_header;
    global $html_footer;
    return $html_header . "\n" . $content . "\n" . $html_footer;
}

main();
