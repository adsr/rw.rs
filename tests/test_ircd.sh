#!/bin/bash

assert yes \
    "$(test_cmd '{ timeout 5 nc -v localhost 6667 | grep -q NOTICE; } && echo yes || echo no')" \
    'ircd should be serving'
