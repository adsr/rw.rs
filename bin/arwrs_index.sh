#!/bin/bash
set -eu

source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"

if [ -f "${arwrs_db_prefix}.idx" ]; then
    $crawdb_dir/crawdb \
        -i "${arwrs_db_prefix}.idx" \
        -d "${arwrs_db_prefix}.dat" \
        -I
fi
