#!/bin/bash

assert yes \
    "$(test_cmd '{ curl -v localhost 2>&1 | grep -q "200 OK"; } && echo yes || echo no')" \
    'httpd should serve a 200'
