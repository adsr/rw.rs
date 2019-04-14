#!/bin/bash
set -eu
source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"

git -C "$rwrs_root" reset --hard
git -C "$rwrs_root" clean -fdx
git -C "$rwrs_root" pull --rebase
