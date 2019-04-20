#!/bin/bash

assert yes \
    $(test_cmd 'ping -W5 -c1 github.com &>/dev/null && echo yes || echo no') \
    'should be able to ping GitHub'
