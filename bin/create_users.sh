#!/bin/bash
set -eu
source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"

log_ns='create_users.sh'

comm -13 <(cut -d: -f1 /etc/passwd | sort) <(ls -1 "$rwrs_root/users" | sort) | while read uname; do
    uname_len=$(echo "$uname" | wc -c)
    if [ "$uname_len" -gt "$max_uname_len" ]; then
        logger -t $log_ns "Skipping long username $uname"
        continue
    fi
    uname_dir="$rwrs_root/users/$uname"
    adduser --disabled-password --gecos '' $uname
    uid=$(id -u $uname)
    ln -s $restricted_slice_dir "/etc/systemd/system/user-$uid.slice.d"
    home_dir=$(getent passwd $uname | cut -d: -f6)
    ssh_dir="$home_dir/.ssh"
    mkdir -vp $ssh_dir
    chmod -v 700 $ssh_dir
    cp -vf "$uname_dir/authorized_keys" $ssh_dir
    echo $default_user_motd >"$home_dir/motd"
    chown -vR "$uname:$uname" $home_dir
    logger -t $log_ns "Created user $uname"
done
