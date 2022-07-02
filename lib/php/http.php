<?php

/**
 * Parse incoming HTTP request from `$fd_in`, invoke `$handler_fn`, write HTTP
 * response to `$fd_out`. STDIN and STDOUT are used by default.
 *
 * Example:
 *
 * ```php
 * http_handle(function($request, $set_code_fn, $set_header_fn) {
 *   switch ($request['uri_parts']['path'] ??) {
 *      case '/~adsr/hello':
 *        echo 'hello';
 *        break;
 *      case '/~adsr/echo.json':
 *        $set_header_fn('Content-Type', 'application/json');
 *        echo json_encode($request);
 *        break;
 *      default:
 *        $set_code_fn(404);
 *        break;
 *   }
 * });
 * ```
 *
 * @param callable $handler_fn
 * @param resource $fd_in
 */
function http_handle($handler_fn, $fd_in = null, $fd_out = null) {
    // Read from stdin by default
    if ($fd_in === null) {
        $fd_in = STDIN;
    }

    // Write to stdout by default
    if ($fd_out === null) {
        $fd_out = STDOUT;
    }

    // Read request until \r\n\r\n
    $request_data = '';
    $header_len = 0;
    do {
        if (($chunk = fread($fd_in, 1024)) === false) {
            break;
        }
        $request_data .= $chunk;
        $header_len = strpos($request_data, "\r\n\r\n");
    } while ($header_len === false);

    // Setup parse_headers_fn
    $parse_headers_fn = function($header_lines) {
        return array_reduce($header_lines, function($headers, $item) {
            if (strlen(trim($item)) > 0) {
                $parts = explode(':', $item, 2);
                $headers[strtolower(trim($parts[0]))] = ltrim($parts[1] ?? '');
            }
            return $headers;
        }, []);
    };

    // Parse headers
    $header_data = substr($request_data, 0, $header_len);
    $header_lines = explode("\r\n", $header_data);
    $request_line = array_shift($header_lines);
    $headers = $parse_headers_fn($header_lines);

    // Read remaining content
    $content_len = (int)($headers['content-length'] ?? 0);
    $total_len = $content_len + $header_len + 4;
    while (strlen($request_data) < $total_len) {
        $remaining_len = $total_len - strlen($request_data);
        $chunk = fread($fd_in, $remaining_len);
        if ($chunk !== false) {
            $request_data .= $chunk;
        } else {
            break;
        }
    }
    $content = substr($request_data, $header_len + 4);

    // Handle multipart/form-data
    $boundary = null;
    $matches = null;
    if (preg_match('|^multipart/form-data;\s*boundary=(.+)|im', $headers['content-type'] ?? '', $matches)) {
        $boundary = $matches[1];
    }

    // Parse out HTTP verb, URI, and protocol
    $verb = null;
    $uri = null;
    $protocol = null;
    if (preg_match('/^(\S+)\s*(\S+)\s*(.*)/', $request_line, $matches)) {
        $verb = $matches[1];
        $uri = $matches[2];
        $protocol = $matches[3];
    }

    // Parse URI and query string
    $uri_parts = parse_url($uri ?? '');
    $params = [];
    parse_str($uri_parts['query'] ?? '', $params);

    // Extract multipart/form-data
    if ($boundary !== null) {
        $multi_parts = explode("\r\n--$boundary\r\n", $content);
        $multi_parts[0] = preg_replace('/^--' . preg_quote($boundary, '/') . "\r\n/m", '', $multi_parts[0]);
        $multi_parts[count($multi_parts) - 1] = rtrim(preg_replace('/^--' . preg_quote($boundary, '/') . "--/m", '', $multi_parts[count($multi_parts) - 1]));
        foreach ($multi_parts as $multi_part) {
            $rnrn = strrpos($multi_part, "\r\n\r\n");
            if ($rnrn !== false) {
                $mp_content = substr($multi_part, $rnrn + 4);
                $mp_header_data = substr($multi_part, 0, $rnrn);
            } else {
                $mp_content = '';
                $mp_header_data = $multi_part;
            }
            $mp_header_lines = explode("\r\n", $mp_header_data);
            $mp_headers = $parse_headers_fn($mp_header_lines);
            if (preg_match('/[;:]\s*name="([^"]+)"/i', $mp_headers['content-disposition'] ?? '', $matches)) {
                $param_name = $matches[1];
                if (substr($param_name, -2) === '[]') {
                    $params[$matches[1]][] = $mp_content;
                } else {
                    $params[$matches[1]] = $mp_content;
                }
            }
        }
    } else if ($verb === 'POST') {
        $post_params = [];
        parse_str($content ?? '', $post_params);
        $params = array_merge($params, $post_params);
    }

    // Init response
    $resp_line = '200 OK';
    $resp_headers = [];
    $resp_wrote_headers = false;

    // Setup write_fn
    $write_fn = function($data) use (&$resp_wrote_headers, &$resp_line, &$resp_headers, $fd_out) {
        if (!$resp_wrote_headers) {
            fwrite($fd_out, "HTTP/1.1 $resp_line\r\n");
            foreach ($resp_headers as $k => $v) {
                fwrite($fd_out, "$k: $v\r\n");
            }
            fwrite($fd_out, "\r\n");
            $resp_wrote_headers = true;
        }
        fwrite($fd_out, $data);
    };

    // Setup set_resp_header_fn
    $set_resp_header_fn = function($header, $value) use (&$resp_headers, &$resp_wrote_headers) {
        if ($resp_wrote_headers) {
            return false;
        }
        $resp_headers[strval($header)] = strval($value);
        return true;
    };

    // Setup set_resp_code_fn
    $set_resp_code_fn = function($code) use (&$resp_line, &$resp_wrote_headers) {
        if ($resp_wrote_headers) {
            return false;
        }
        $resp_code_map = [
            100 => 'Continue',
            101 => 'Switching Protocols',
            200 => 'OK',
            201 => 'Created',
            202 => 'Accepted',
            203 => 'Non-Authoritative Information',
            204 => 'No Content',
            205 => 'Reset Content',
            206 => 'Partial Content',
            300 => 'Multiple Choices',
            301 => 'Moved Permanently',
            302 => 'Found',
            303 => 'See Other',
            304 => 'Not Modified',
            305 => 'Use Proxy',
            306 => 'Switch Proxy',
            307 => 'Temporary Redirect',
            400 => 'Bad Request',
            401 => 'Unauthorized',
            402 => 'Payment Required',
            403 => 'Forbidden',
            404 => 'Not Found',
            405 => 'Method Not Allowed',
            406 => 'Not Acceptable',
            407 => 'Proxy Authentication Required',
            408 => 'Request Timeout',
            409 => 'Conflict',
            410 => 'Gone',
            411 => 'Length Required',
            412 => 'Precondition Failed',
            413 => 'Request Entity Too Large',
            414 => 'Request-URI Too Long',
            415 => 'Unsupported Media Type',
            416 => 'Requested Range Not Satisfiable',
            417 => 'Expectation Failed',
            500 => 'Internal Server Error',
            501 => 'Not Implemented',
            502 => 'Bad Gateway',
            503 => 'Service Unavailable',
            504 => 'Gateway Timeout',
            505 => 'HTTP Version Not Supported',
        ];
        $code = (int)$code;
        if (isset($resp_code_map[$code])) {
            $resp_line = sprintf("%d %s", $code, $resp_code_map[$code]);
            return true;
        }
        return false;
    };

    // Invoke handler
    $request = compact(
        'headers',
        'content',
        'verb',
        'uri',
        'protocol',
        'uri_parts',
        'params',
    );
    ob_start();
    call_user_func(
        $handler_fn,
        $request,
        $set_resp_code_fn,
        $set_resp_header_fn,
        $write_fn,
    );
    call_user_func($write_fn, ob_get_clean());
}

function http_test_assert($expected, $actual, $what) {
    if ($expected !== $actual) {
        $result = 'FAIL';
        $color = 31;
        $reason = sprintf("expected %s but saw %s", json_encode($expected), json_encode($actual));
    } else {
        $result = 'PASS';
        $color = 32;
        $reason = '';
    }
    printf("%24s: \x1b[%dm%s\x1b[0m %s\n", $what, $color, $result, $reason);
}

function http_handle_test() {
    $in = fopen('php://memory', 'r+');
    $out = fopen('php://memory', 'r+');
    $handler = function($req, $set_code, $set_header, $write) {
        $resp_code = $req['params']['resp_code'] ?? '200';
        $resp_header_field = $req['params']['resp_header_field'] ?? null;
        $resp_header_value = $req['params']['resp_header_value'] ?? null;
        $resp_data = $req['params']['resp_data'] ?? '';
        $resp_params = $req['params']['resp_params'] ?? null;
        $set_code($resp_code);

        if ($resp_header_field && $resp_header_value) {
            $set_header($resp_header_field, $resp_header_value);
        }

        if ($resp_params) {
            echo json_encode($req['params']);
        } else {
            echo $resp_data;
        }
    };

    ftruncate($in, 0);
    ftruncate($out, 0);
    fwrite($in, "GET /?resp_data=42 HTTP/1.1\r\n\r\n");
    rewind($in);
    http_handle($handler, $in, $out);
    rewind($out);
    http_test_assert("HTTP/1.1 200 OK\r\n\r\n42", stream_get_contents($out), 'simple_get_200');

    ftruncate($in, 0);
    ftruncate($out, 0);
    fwrite($in, "GET /?resp_data=woops&resp_code=404&resp_header_field=Content-Type&resp_header_value=text/plain HTTP/1.1\r\n\r\n");
    rewind($in);
    http_handle($handler, $in, $out);
    rewind($out);
    http_test_assert("HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\n\r\nwoops", stream_get_contents($out), 'simple_get_404');

    ftruncate($in, 0);
    ftruncate($out, 0);
    fwrite($in, "POST /?resp_params=1 HTTP/1.1\r\nContent-Length: 12\r\n\r\nbob=an+uncle");
    rewind($in);
    http_handle($handler, $in, $out);
    rewind($out);
    http_test_assert("HTTP/1.1 200 OK\r\n\r\n{\"resp_params\":\"1\",\"bob\":\"an uncle\"}", stream_get_contents($out), 'simple_post');
}

if (!empty(getenv('RWRS_HTTP_TEST', true))) {
    http_handle_test();
}
