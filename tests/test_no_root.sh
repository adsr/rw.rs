#!/bin/bash

assert ok \
    $(test_cmd "{ touch /hello &>/dev/null && echo fail; } || echo ok") \
    "should not be able to make a file at /hello"
