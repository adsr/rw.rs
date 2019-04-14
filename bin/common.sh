#!/bin/bash

rwrs_root="$(dirname $(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd))"
rwrs_url='https://github.com/adsr/rw.rs'
max_uname_len=10
restricted_slice_dir=/etc/systemd/system/user-restricted.slice.d
default_user_motd='...'
