#!/bin/bash
set -eu
source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"

log_ns='update_restricted_slice_conf.sh'

# set allowed domains
allowed_domains=$(cat <<'EOD'
    aussies.space
    chat.freenode.net
    club.tilde.chat
    cosmic.voyage
    ctrl-c.club
    envs.net
    github.com
    irc.data.lt
    irc.ktu.lt
    irc.libera.chat
    irc.oftc.net
    radiofreqs.space
    raw.githubusercontent.com
    thunix.net
    tilde.black
    tilde.chat
    tilde.club
    tilde.institute
    tilde.pink
    tilde.team
    tilde.town
    tildeverse.org
    wilde.ftp.sh
    yourtilde.com
EOD
)

# get A records for each domain
ip_address_allow=''
for allowed_domain in $allowed_domains; do
    ip_address_allow+="# $allowed_domain"$'\n'
    for a_record in $(dig +noall +answer $allowed_domain | awk '$4=="A"{print $5}'); do
        ip_address_allow+="IPAddressAllow=$a_record"$'\n'
    done
    ip_address_allow+=$'\n'
done

# write temp restricted_slice_file
tmpf=$(mktemp 'update_restricted_slice_conf.XXXXXXXXXX')
while IFS= read -r line; do
    echo $line >>$tmpf
    if [ "$line" = "# BEGIN update_restricted_slice_conf.sh" ]; then
        echo "$ip_address_allow" >>$tmpf
    fi
done <$restricted_slice_template

# update and reload systemd if different
if ! diff $restricted_slice_file $tmpf; then
    mkdir -p $(dirname $restricted_slice_file)
    cp -vf $tmpf $restricted_slice_file
    systemctl daemon-reload
    logger -t $log_ns "updated $restricted_slice_file"
fi
rm -f $tmpf
