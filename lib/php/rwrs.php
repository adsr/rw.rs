<?php

function rwrs_config($name) {
    $rwrs_root = dirname(dirname(realpath(__DIR__)));
    $bin_dir = sprintf('%s/bin', $rwrs_root);
    $cmd = sprintf('source %s/common.sh; v=%s; echo ${!v}', $bin_dir, escapeshellarg($name));
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
