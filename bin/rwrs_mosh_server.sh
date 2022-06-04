#!/bin/bash
set -euo pipefail

die() { echo "$@" >&2; exit 1; }

[ -n "$SUDO_USER" ] || die "Expected SUDO_USER env"
[ -n "$SUDO_UID" ]  || die "Expected SUDO_UID env"

pkill -9 -x mosh-server -u $SUDO_USER || true

exec \
    systemd-run -q --scope --slice system.slice \
    mosh-server new -c 256 -p 0 -- \
    systemd-run -q --scope --slice "user-$SUDO_UID.slice" \
    su -l $SUDO_USER
