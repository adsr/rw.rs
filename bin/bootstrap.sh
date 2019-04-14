#!/bin/bash
set -eu
source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"

apt install -y build-essential libtool sudo net-tools curl git zsh vim emacs nano mle screen tmux irssi weechat inspircd

cp -vf "$rwrs_root/config/sshd_config" /etc/ssh/
systemctl restart sshd

mkdir -p $restricted_slice_dir
cp -vf "$rwrs_root/config/user-restricted.slice.conf" $restricted_slice_dir
systemctl daemon-reload

cp -vf "$rwrs_root/config/cron" /etc/cron.d/rw-rs

# TODO configure ircd

# TODO configure apache with per-user web dirs

# TODO simple alerting
