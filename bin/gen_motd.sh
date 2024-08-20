#!/bin/bash
set -eu
source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"

{
    echo '   ______     __     __       ______     ______'
    echo '  /\  == \   /\ \  _ \ \     /\  == \   /\  ___\'
    echo '  \ \  __<   \ \ \/ ^.\ \    \ \  __<   \ \___  \'
    echo '   \ \_\ \_\  \ \__/^. \_\    \ \_\ \_\  \/\_____\'
    echo '    \/_/ /_/   \/_/   \/_/  .  \/_/ /_/   \/_____/'
    echo
    echo "   MOTD generated $(date)"
    echo '   (Psst, write up to 24 bytes in a file called ~/motd)'
    echo
    find /home -maxdepth 2 -type f -name motd | sort | while read motd_path; do
        user=$(echo $motd_path | cut -d/ -f3)
        motd=$(
            timeout 1 sed -E \
                -e 's/[^[:graph:][:space:]]//g' \
                -e 's/[[:space:]]+/ /g' \
                -e 's/^(.{0,24}).*$/\1/' \
                $motd_path \
            || true
        )
        printf "%${max_uname_len}s: %-24s\n" "$user" "$motd"
    done | column -xc 80
    echo
    echo "   $rwrs_url"
    echo
} >/etc/motd
