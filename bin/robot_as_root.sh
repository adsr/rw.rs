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
    cat | su -s/bin/bash -c "base64 -d >$printcap_image.bak" apache
    file -i $printcap_image.bak | grep image/webp && mv -f $printcap_image.bak $printcap_image
}

main
