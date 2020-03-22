#!/bin/bash

assert ok \
    "$(test_cmd 'echo ok')" \
    "should be able to execute commands remotely"
