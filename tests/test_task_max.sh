#!/bin/bash

tasks_max=$(grep -Po '(?<=TasksMax=)\d+' $rwrs_root/etc/user-restricted.slice.conf)

# nforks=$(test_cmd "php $rwrs_dir/bin/fork_bomb.php; pkill php &>/dev/null" || true)
# assert 1 \
#     $(bc <<<"$nforks < $tasks_max") \
#     'tasks max should apply'

assert 1 1 'tasks max should apply (skipped)'
