#!/bin/bash

pcpu_limit=$(grep -Po '(?<=CPUQuota=)\d+(?=%)' $rwrs_root/etc/user-restricted.slice.conf)
pcpu_limit_grace=10.0

pcpu=$(test_cmd 'yes >/dev/null & sleep 1; ps -ho %cpu $!; kill $!; wait; true')

assert 1 \
    $(bc <<<"$pcpu < ($pcpu_limit + $pcpu_limit_grace)") \
    'cpu quota should apply'
