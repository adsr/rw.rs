#!/bin/bash
set -eu
source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"

log_ns='update_restricted_slice_conf.sh'

# set allowed domains
allowed_domains=$(cat <<'EOD'
    aussies.space
    banner.tildeverse.org
    breadpunk.club
    cosmic.voyage
    crawl.tildeverse.org
    ctrl-c.club
    drone.tildegit.org
    envs.net
    factorio.tildeverse.org
    github.com
    gopher.tildeverse.org
    heathens.club
    intranet.tildeverse.org
    jitsi.tildeverse.org
    journal.tildeverse.org
    lists.tildeverse.org
    mc.tildeverse.org
    medium.com
    modded.tildeverse.org
    news.tildeverse.org
    pad.tildeverse.org
    paste.tildeverse.org
    pleroma.tilde.zone
    quotes.tilde.chat
    raw.githubusercontent.com
    rfc.tildeverse.org
    rss.tildeverse.org
    search.tildeverse.org
    slbr.tildeverse.org
    sr.ht
    stats.foldingathome.org
    texto-plano.xyz
    thunix.net
    tilde.chat
    tilde.club
    tildegit.org
    tilde.institute
    tilde.news
    tildenic.org
    tilde.pink
    tilderadio.org
    tilde.team
    tilde.town
    tildeverse.org
    tilde.wiki
    tilde.zone
    ttm.sh
    wilde.ftp.sh
    write.tildeverse.org
    yourtilde.com
    zine.tildeverse.org
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
