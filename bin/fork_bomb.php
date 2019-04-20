<?php

error_reporting(0);

$nforks = 0;

while (1) {
    $rv = pcntl_fork();
    if ($rv > 0) {
        $nforks += 1;
    } else if ($rv === 0) {
        sleep(PHP_INT_MAX);
    } else {
        break;
    }
}

echo $nforks . PHP_EOL;
