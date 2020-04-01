#!/usr/bin/env php
<?php

require 'rwrs.php';

define('PRINTCAP_CUPS_DEST', 'Zijiang-ZJ-58');
define('PRINTCAP_VIDEO_DEV', '/dev/video0');
define('PRINTCAP_QUEUE_URL', 'http://print.rw.rs/queue');
define('PRINTCAP_LAST_ETAG_PATH', '/home/adam/.printcap/last_etag');
define('PRINTCAP_LAST_TS_PATH', '/home/adam/.printcap/last_ts');
define('PRINTCAP_FFMPEG_BIN', '/home/adam/ffmpeg/bin/ffmpeg');
define('PRINTCAP_ROBOT_KEY', '/home/adam/.ssh/id_rsa_rwrs_robot');

function printcap_main() {
    // Get queue from rw.rs
    $new_etag = null;
    $jobs = printcap_get_queue($new_etag);

    // Read last_ts from disk
    $last_ts = (float)(@file_get_contents(PRINTCAP_LAST_TS_PATH) ?: microtime(true));

    // Set ctx
    $ctx = (object)[
        'last_ts' => $last_ts,
        'max_name_len' => rwrs_config_require('printcap_max_name_len'),
        'max_msg_len' => rwrs_config_require('printcap_max_msg_len'),
        'max_bytes_factor' => rwrs_config_require('printcap_max_bytes_factor'),
    ];

    // Process each job in queue
    // Keep track of latest job ts
    $max_ts = $last_ts;
    foreach ($jobs as $job) {
        $job_ts = 0;
        if (printcap_handle_job($job, $ctx, $job_ts)) {
            $max_ts = max($max_ts, $job_ts);
        }
    }

    // Sleep a bit and upload a picture
    sleep(10);
    $rwrs_cmd = 'sudo /opt/rw.rs/bin/robot_as_root.sh printcap_upload';
    $cmd = sprintf(
        '%s -f video4linux2 -i %s -vframes 1 -f webp -vf %s - | base64 | ssh -i %s robot@rw.rs %s',
        escapeshellarg(PRINTCAP_FFMPEG_BIN),
        escapeshellarg(PRINTCAP_VIDEO_DEV),
        escapeshellarg('drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf:fontcolor=green:text=%{gmtime}:x=10:y=10'),
        escapeshellarg(PRINTCAP_ROBOT_KEY),
        escapeshellarg($rwrs_cmd)
    );
    exec($cmd, $output, $exit_code);

    // Write last_ts and new_etag to disk
    if (!file_exists(dirname(PRINTCAP_LAST_TS_PATH))) {
        mkdir(dirname(PRINTCAP_LAST_TS_PATH));
    }
    file_put_contents(PRINTCAP_LAST_TS_PATH, $max_ts);
    if ($new_etag) {
        file_put_contents(PRINTCAP_LAST_ETAG_PATH, $new_etag);
    }
}

function printcap_handle_job($job, $ctx, &$job_ts) {
    // Parse job
    $parts = explode(' ', $job, 3);

    $ts = (float)($parts[0] ?? 0);
    $name = @base64_decode($parts[1] ?? '', true);
    $msg = @base64_decode($parts[2] ?? '', true);

    if (!$ts || !$msg || !$name) {
        fwrite(STDERR, "skipping malformed job; job=$job\n");
        return false;
    }

    // Check if already processed
    if ($ts <= $ctx->last_ts) {
        return false;
    }

    // Convert to ESC/POS and check resulting lengths
    $name_len = 0;
    $msg_len = 0;
    $esc_pos_name = printcap_str_to_esc_pos($name, $ctx, $name_len);
    $esc_pos_msg = printcap_str_to_esc_pos($msg, $ctx, $msg_len);

    if ($name_len < 1 || $name_len > $ctx->max_name_len
        || strlen($name) > $ctx->max_name_len * $ctx->max_bytes_factor
    ) {
        fwrite(STDERR, "name empty or too long; job=$job\n");
        return false;
    }

    if ($msg_len < 1 || $msg_len > $ctx->max_msg_len
        || strlen($msg) > $ctx->max_msg_len * $ctx->max_bytes_factor
    ) {
        fwrite(STDERR, "msg empty or too long; job=$job\n");
        return false;
    }

    // Assemble ESC/POS command
    $esc_pos_cmd  = "\x1b@";      // init
    $esc_pos_cmd .= "\x1bM\x01";  // small font size
    $esc_pos_cmd .= $msg_esc_pos . "\n";
    $esc_pos_cmd .= str_repeat(' ', max(0, $ctx->max_msg_len - $name_len));
    $esc_pos_cmd .= $name_esc_pos . "\n\n";

    // Send to printer
    $esc_pos_cmd_64 = base64_encode($esc_pos_cmd);
    $cmd = sprintf(
        'echo %s | base64 -d | timeout 5 lp -d %s',
        escapeshellarg($esc_pos_cmd_64),
        escapeshellarg(PRINTCAP_CUPS_DEST)
    );

    $output = [];
    $exit_code = 1;
    // exec($cmd, $output, $exit_code);

    echo $cmd;
    $exit_code = 0;

    if ($exit_code !== 0) {
        fwrite(STDERR, "failed to print job; job=$job\n");
        return false;
    }

    echo "sent job to printer; job=$job\n";
    $job_ts = $ts;
    return true;
}

function printcap_str_to_esc_pos($str, $ctx, &$printable_len) {
    $esc_pos = '';
    $bold = false;
    $uline = false;
    $invert = false;
    $printable_len = 0;
    for ($i = 0; $i < strlen($str); $i++) {
        $c = substr($str, $i, 1);
        $k = ord($c);
        if ($k >= 0x20 && $k <= 0xff) {
            // Printable
            $esc_pos .= $c;
            $printable_len += 1;
        } else if ($k === 0x01) {
            // Toggle bold
            $bold = !$bold;
            $esc_pos .= "\x1bE" . ($bold ? "\x01" : "\x00");
        } else if ($k === 0x02) {
            // Toggle underline
            $uline = !$uline;
            $esc_pos .= "\x1b-" . ($uline ? "\x01" : "\x00");
        } else if ($k === 0x03) {
            // Toggle inverted
            $invert = !$invert;
            $esc_pos .= "\x1dB" . ($invert ? "\x01" : "\x00");
        }
    }
    return $esc_pos;
}

function printcap_get_queue(&$new_etag) {
    // Read last ETag from disk
    $last_etag = trim(@file_get_contents(PRINTCAP_LAST_ETAG_PATH) ?: '-');

    // Curl rw.rs for queue
    $cmd = sprintf(
        "curl -f -m5 -s -i -H %s %s | tr -d '\\r'",
        escapeshellarg("If-None-Match: " . $last_etag),
        escapeshellarg(PRINTCAP_QUEUE_URL)
    );
    $output = [];
    $exit_code = 1;
    exec($cmd, $output, $exit_code);
    if ($exit_code !== 0) {
        rwrs_croak("curl failed\n");
    }
    $header_queue = implode("\n", $output);

    // Look at HTTP headers
    $http_line = strtok($header_queue, "\n");
    if (preg_match('|^HTTP/1.1 304 Not Modified$|', $http_line)) {
        echo "curl returned 304\n";
        exit(0);
    }
    if (!preg_match('|^HTTP/1.1 200 OK$|', $http_line)) {
        rwrs_croak("curl received non-200\n");
    }

    // Parse out new ETag
    $m = null;
    if (preg_match('|(?<=^ETag: ).+$|m', $header_queue, $m)) {
        $new_etag = trim($m[0]);
    }

    // Parse out response body (minus headers)
    if (!preg_match('|(?<=\n\n).*|sm', $header_queue, $m)) {
        rwrs_croak("failed to find queue content\n");
    }

    // Explode headers into array
    $queue = trim($m[0]);
    if (empty($queue)) {
        return [];
    }
    return explode("\n", $queue);
}

printcap_main();
