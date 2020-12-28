#!/bin/bash
set -eu
source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"

uname=${1:-}
maybe_dry_run='echo dry_run:'
[ "${2:-}" = "wet_run" ] && maybe_dry_run=''

# show usage if uname empty
if [ -z "$uname" ]; then
    echo "Usage: $0 <uname> [wet_run]" >&2
    exit 1
fi

# ensure uname exists
if ! id "$uname" &>/dev/null; then
    echo "User $uname not found" >&2
    exit 1
fi

# get uid and home_dir
uid=$(id -u $uname)
home_dir=$(getent passwd $uname | cut -d: -f6)

# remove user
$maybe_dry_run deluser $uname

# remove home dir
$maybe_dry_run rm -rf $home_dir

# remove systemd slice
$maybe_dry_run rm -f "/etc/systemd/system/user-$uid.slice.d"
$maybe_dry_run systemctl daemon-reload
