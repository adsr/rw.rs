#!/bin/bash

assert ok \
    $(test_cmd "{ timeout 1 chsh -s/bin/bash && echo ok; } || echo fail") \
    "should be able to change own shell"

assert ok \
    $(test_cmd "{ timeout 1 chsh -s/bin/bash adsr && echo fail; } || echo ok") \
    "should not be able to change other user's shell"
