#!/bin/bash

assert yes \
    "$(test_cmd '{ curl -H "Host: rw.rs" -v localhost 2>&1 | grep -q "200 OK"; } && echo yes || echo no')" \
    'httpd should serve a 200 for rw.rs'

assert yes \
    "$(test_cmd '{ curl -H "Host: www.rw.rs" -v localhost 2>&1 | grep -q "301 Moved"; } && echo yes || echo no')" \
    'httpd should serve a 301 for www.rw.rs'

assert yes \
    "$(test_cmd '{ curl -H "Host: a.rw.rs" -v localhost 2>&1 | grep -q "<h1>a.rw.rs</h1>"; } && echo yes || echo no')" \
    'httpd should serve a 200 via php for a.rw.rs'

assert yes \
    "$(test_cmd '{ curl -H "Host: foobar.rw.rs" -v localhost 2>&1 | grep -q "404 Not Found"; } && echo yes || echo no')" \
    'httpd should serve a 404 for foobar.rw.rs'

assert yes \
    "$(test_cmd '{ curl -H "Host: rw.rs" -v localhost/join.link 2>&1 | grep -q "301 Moved"; } && echo yes || echo no')" \
    'httpd should serve a 301 for rw.rs/join.link'
