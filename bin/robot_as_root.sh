#!/bin/bash
set -eu
source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"

task=${1:-}

main() {
    case $task in
        *) exit 1 ;;
    esac
}

main
