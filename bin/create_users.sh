#!/bin/bash
set -eu
source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"

comm -13 <(cut -d: -f1 /etc/passwd | sort) <(ls -1 "$root/users" | sort) | while read user; do
    user_len=$(echo "$user" | wc -c)
    [ "$user_len" -gt "$max_username_len" ] && exit 1
    user_dir="$root/users/$user"
    adduser --disabled-password --gecos '' $user
    uid=$(id -u $user)
    ln -s $restricted_slice_dir "/etc/systemd/system/user-$uid.slice.d"
    home_dir=$(getent passwd $user | cut -d: -f6)
    ssh_dir="$home_dir/.ssh"
    mkdir -vp $ssh_dir
    chmod -v 700 $ssh_dir
    cp -vf "$user_dir/authorized_keys" $ssh_dir
    echo $default_user_motd >"$home_dir/motd"
    chown -vR "$user:$user" $home_dir
done
