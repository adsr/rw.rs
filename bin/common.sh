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
httpd_var_dir='/var/rw.rs/apache'
htdocs_root="$httpd_root/htdocs"
share_lib_dir='/usr/share/lib'
do_not_pull_fname='.do_not_pull'
php_version='7.4.4'
php_ini_path='/usr/local/lib/php.ini'
swap_path='/root/swap.img'
crawdb_dir="$share_lib_dir/c/crawdb"
arwrs_db_prefix="$httpd_var_dir/arwrs_db"
printcap_image="$httpd_var_dir/print_image.webp"
printcap_queue_path="$httpd_var_dir/print_queue.txt"
printcap_max_name_len=16
printcap_max_msg_len=42
printcap_max_bytes_factor=3
