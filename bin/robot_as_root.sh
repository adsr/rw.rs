#!/bin/bash
set -eu
source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"

task=${1:-}

main() {
    case $task in
        printcap_upload) $task ;;
        *) exit 1 ;;
    esac
}

printcap_upload() {
    cat | su -c "base64 -d >$printcap_image" apache
}

main
