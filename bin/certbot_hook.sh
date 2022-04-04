#!/bin/bash
source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"

acme_dir=$httpd_root/htdocs/main/.well-known/acme-challenge
mkdir -p $acme_dir
echo $CERTBOT_VALIDATION >$acme_dir/$CERTBOT_TOKEN
