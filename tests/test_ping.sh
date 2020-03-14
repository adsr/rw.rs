#!/bin/bash

for hostname in github.com club.tilde.chat raw.githubusercontent.com; do
    assert yes \
        $(test_cmd "ping -W5 -c1 $hostname &>/dev/null && echo yes || echo no") \
        "should be able to ping $hostname"
done
