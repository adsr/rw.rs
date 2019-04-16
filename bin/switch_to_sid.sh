#!/bin/bash
set -eu
source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"

tee /etc/apt/sources.list <<'EOD'
deb http://ftp.us.debian.org/debian/ testing main
deb-src http://ftp.us.debian.org/debian/ testing main
EOD
apt update -y
apt dist-upgrade -y
read -p 'Reboot? (y/n):' yesno
[ "$yesno" == "y" ] && shutdown -r now
