#!/bin/bash

assert ok \
    $(test_cmd "fallocate -l $quota_hard big &>/dev/null || echo ok; rm -f big") \
    'disk quota should apply'
