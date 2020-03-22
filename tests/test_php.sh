#!/bin/bash

assert 4242 \
    $(test_cmd 'php -r "echo 4242;"') \
    'should be able to run php'
