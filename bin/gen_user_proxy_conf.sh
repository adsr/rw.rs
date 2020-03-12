#!/bin/bash
set -eu
source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"

old_conf="$httpd_root/conf/user_proxy.conf"
new_conf="${old_conf}.new"

echo '' >$new_conf
for uname in $(ls -1 "$rwrs_root/users" | sort); do
    echo "ProxyPassMatch \"/~$uname/proxy(/.*)?$\" \"unix:/home/$uname/public_html/proxy.sock|http://$uname\"" >>$new_conf
done

if ! diff $new_conf $old_conf; then
    cp -vf $new_conf $old_conf
    systemctl reload httpd
fi
rm -f $new_conf
