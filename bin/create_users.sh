#!/bin/bash
set -eu
source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"

log_ns='create_users.sh'

comm -13 <(cut -d: -f1 /etc/passwd | sort) <(ls -1 "$rwrs_root/users" | sort) | while read uname; do
    uname_dir="$rwrs_root/users/$uname"
    auth_keys="$uname_dir/authorized_keys"
    uname_len=$(echo "$uname" | wc -c)
    if [ "$uname_len" -gt "$max_uname_len" ]; then
        logger -t $log_ns "username $uname is too long; skipping"
        continue
    elif [ ! -f "$auth_keys" ]; then
        logger -t $log_ns "missing $auth_keys for $uname; skipping"
        continue
    fi
    adduser --disabled-password --gecos '' $uname
    setquota -u $uname $quota_soft $quota_hard 0 0 -a
    uid=$(id -u $uname)
    ln -s $restricted_slice_dir "/etc/systemd/system/user-$uid.slice.d"
    systemctl daemon-reload
    home_dir=$(getent passwd $uname | cut -d: -f6)
    ssh_dir="$home_dir/.ssh"
    mkdir -vp $ssh_dir
    chmod -v 700 $ssh_dir
    cp -vf $auth_keys $ssh_dir
    echo $default_user_motd >"$home_dir/motd"
    chown -vR "$uname:$uname" $home_dir
    logger -t $log_ns "created user $uname"
done
