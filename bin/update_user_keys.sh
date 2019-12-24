#!/bin/bash
set -eu
source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"

log_ns='update_user_keys.sh'

ls -1 "$rwrs_root/users" | sort | while read uname; do
    repo_auth_keys="$rwrs_root/users/$uname/authorized_keys"
    home_dir=$(getent passwd $uname | cut -d: -f6)
    ssh_dir="$home_dir/.ssh"
    home_auth_keys="$ssh_dir/authorized_keys"
    if ! diff $repo_auth_keys $home_auth_keys; then
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        cp -vf $repo_auth_keys $home_auth_keys
        chown -v -R "$uname:$uname" $ssh_dir
        logger -t $log_ns "updated ssh keys for $uname"
    fi
done
