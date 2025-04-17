#!/bin/bash
set -euo pipefail
source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"

duration=1w
max_fails=14
tmp_dir=$(mktemp -d /tmp/deny_hosts.XXXXXXXXXX)
log_ns='deny_hosts.sh'

cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

# Find successful and failed SSH logins
journalctl --since="-${duration}" --unit=ssh >"$tmp_dir/all"
grep -Po 'Accepted publickey for .+ from \S+' "$tmp_dir/all" | \
    awk '{print "sshd: " $NF}' | \
    sort -u \
    >"$tmp_dir/allow"
grep -Po '(?<=Connection from )\S+' "$tmp_dir/all" | \
    sort | uniq -c | sort -rn | \
    awk -v "n=$max_fails" '$1 >= n {print "sshd: " $2}' | \
    sort \
    >"$tmp_dir/deny"
wc -l "$tmp_dir"/{all,allow,deny}

# Append successful IPs to allow list
grep -v -e '^#' -e '^$' /etc/hosts.allow >"$tmp_dir/hosts.allow" || true
cat "$tmp_dir/allow" >>"$tmp_dir/hosts.allow"
sort --output="$tmp_dir/hosts.allow" --unique "$tmp_dir/hosts.allow"
if ! diff "$tmp_dir/hosts.allow" /etc/hosts.allow; then
    logger -t $log_ns 'updating /etc/hosts.allow'
    mv -vf "$tmp_dir/hosts.allow" /etc/hosts.allow
fi

# Deny failed IPs not in allow list
comm -13 /etc/hosts.allow "$tmp_dir/deny" >"$tmp_dir/hosts.deny"
if ! diff "$tmp_dir/hosts.deny" /etc/hosts.deny; then
    logger -t $log_ns 'updating /etc/hosts.deny'
    mv -vf "$tmp_dir/hosts.deny" /etc/hosts.deny
fi
