#!/bin/bash

cmd=''
cmd+='curl -m5 -s -H "Host: a.rw.rs" -d url=http://cool.com -d path=cool -d g-recaptcha-response=1 localhost/shorten &>/dev/null; '
cmd+='{ curl -m5 -v -H "Host: a.rw.rs" localhost/cool 2>&1 | grep -q "Location: http://cool.com"; } && echo ok || echo fail;'

assert 'ok' \
    "$(test_cmd "$cmd")" \
    'a.rw.s url shortener should work'
