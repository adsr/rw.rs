<?php

function rwrs_config($name) {
    $rwrs_root = dirname(dirname(realpath(__DIR__)));
    $bin_dir = sprintf('%s/bin', $rwrs_root);
    $cmd = sprintf('source %s/common.sh; v=%s; [ -z "${!v+x}" ] && exit 1; echo ${!v}', $bin_dir, escapeshellarg($name));
    $cmd = sprintf('bash -c %s 2>/dev/null', escapeshellarg($cmd));
    $output = [];
    $exit_code = 1;
    exec($cmd, $output, $exit_code);
    if ($exit_code !== 0) {
        return false;
    }
    return $output[0] ?? '';
}

function rwrs_config_require($name) {
    $rv = rwrs_config($name);
    if ($rv === false) {
        exit(1);
    }
    return $rv;
}

function rwrs_croak($msg) {
    fwrite(STDERR, $msg);
    exit(1);
}

function rwrs_valid_captcha($captcha_response) {
    // Verify captcha
    // Skip for localhost
    $ip = $_SERVER['REMOTE_ADDR'] ?? '';
    if (in_array($ip, ['::1', '127.0.0.1']) || preg_match('/^10\.\d+\.\d+\.\d+$/', $ip)) {
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
