#!/bin/bash

rwrs_root="$(dirname $(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd))"
rwrs_dir='/opt/rw.rs'
rwrs_url='https://github.com/adsr/rw.rs'
repo_url='https://github.com/adsr/rw.rs.git'
max_uname_len=10
restricted_slice_dir=/etc/systemd/system/user-restricted.slice.d
quota_path='/'
quota_soft='960M'
quota_hard='1024M'
default_user_motd='...'
httpd_version='2.4.39'
httpd_root='/usr/httpd'
htdocs_root="$httpd_root/htdocs"
do_not_pull_fname='.do_not_pull'
