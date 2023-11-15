#!/bin/bash
source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"

test -f $cert_priv || exit 0 # missing key == expired

expiry_date=$(certbot certificates -d rw.rs | grep 'Expiry Date:' | awk '{print $3 " " $4}')
test -n "$expiry_date" || exit 0 # missing date == expired

expiry_ts=$(date -d "$expiry_date" +%s)
test -n "$expiry_ts" || exit 0 # invalid date == expired

now_ts=$(date +%s)
rem_s=$((expiry_ts-now_ts))

test $rem_s -gt $cert_renew_before_s || exit 0 # about to expire or already expired

exit 1 # not expired
