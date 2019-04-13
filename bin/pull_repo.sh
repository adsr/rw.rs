#!/bin/bash
set -eu
source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"

git -C "$root" reset --hard
git -C "$root" clean -fdx
git -C "$root" pull --rebase
