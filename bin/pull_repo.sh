#!/bin/bash
set -eu
source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"

[ -f "$rwrs_root/$do_not_pull_fname" ] && exit

git -C "$rwrs_root" reset --hard
git -C "$rwrs_root" clean -fd
git -C "$rwrs_root" pull --rebase
git -C "$rwrs_root" submodule update --recursive --remote
