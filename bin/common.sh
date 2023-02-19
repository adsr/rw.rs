#!/bin/bash

rwrs_root="$(dirname $(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd))"
rwrs_dir='/opt/rw.rs'
rwrs_url='https://github.com/adsr/rw.rs'
repo_url='https://github.com/adsr/rw.rs.git'
max_uname_len=10
restricted_slice_dir=/etc/systemd/system/user-restricted.slice.d
restricted_slice_file="$restricted_slice_dir/user-restricted.slice.conf"
restricted_slice_template="$rwrs_root/etc/user-restricted.slice.conf"
quota_path='/'
quota_soft='960M'
quota_hard='1024M'
default_user_motd='...'
httpd_version='2.4.55'
httpd_root='/usr/httpd'
httpd_var_dir='/var/rw.rs/apache'
htdocs_root="$httpd_root/htdocs"
share_lib_dir='/usr/share/lib'
do_not_pull_fname='.do_not_pull'
php_version='8.2.3'
php_ini_path='/usr/local/lib/php.ini'
swap_path='/root/swap.img'
crawdb_dir="$share_lib_dir/c/crawdb"
arwrs_db_prefix="$httpd_var_dir/arwrs_db"
