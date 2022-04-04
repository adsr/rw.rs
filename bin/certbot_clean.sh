#!/bin/bash
source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"

acme_dir=$httpd_root/htdocs/main/.well-known/acme-challenge
rm -rf $acme_dir
