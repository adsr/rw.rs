#!/bin/bash

for hostname in github.com club.tilde.chat raw.githubusercontent.com irc.libera.chat irc.oftc.net; do
    assert ok \
        $(test_cmd "{ for i in \$(seq 1 5); do ping -W5 -c1 $hostname &>/dev/null && break; done && echo ok; } || echo fail") \
        "should be able to ping $hostname"
done
