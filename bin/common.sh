#!/bin/bash

rwrs_root="$(dirname $(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd))"
rwrs_url='https://github.com/adsr/rw.rs'
max_uname_len=10
restricted_slice_dir=/etc/systemd/system/user-restricted.slice.d
quota_path='/home'
quota_soft='960M'
quota_hard='1024M'
default_user_motd='...'
