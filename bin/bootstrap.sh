#!/bin/bash
set -eux
source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"

# install packages
DEBIAN_FRONTEND=noninteractive \
apt install -yq build-essential libtool libtool-bin sudo quota net-tools curl \
    git zsh vim emacs nano mle screen tmux irssi weechat inspircd subversion \
    libxml2-dev libpcre3-dev strace gdb socat sqlite3 php7.3 fish mosh stow

# configure quota
if [ ! -f /aquota.user ]; then
    awk -vq=$quota_path \
        '{if($2==q){ $4=$4",usrjquota=aquota.user,jqfmt=vfsv1" } print}' \
        /etc/fstab >/etc/fstab.new
    mv -vf /etc/fstab.new /etc/fstab
    mount -vo remount $quota_path
    quotacheck -ucm $quota_path
    quotaon -v $quota_path
fi

# configure sshd
if ! diff "$rwrs_root/etc/sshd_config" /etc/ssh/sshd_config &>/dev/null; then
    cp -vf "$rwrs_root/etc/sshd_config" /etc/ssh/
    systemctl restart sshd
fi

# configure restricted user slice
if ! diff "$rwrs_root/etc/user-restricted.slice.conf" \
          "$restricted_slice_dir/user-restricted.slice.conf" &>/dev/null
then
    mkdir -p $restricted_slice_dir
    cp -vf "$rwrs_root/etc/user-restricted.slice.conf" $restricted_slice_dir
    systemctl daemon-reload
fi

# configure cron
if ! diff "$rwrs_root/etc/cron" /etc/cron.d/rw-rs &>/dev/null; then
    cp -vf "$rwrs_root/etc/cron" /etc/cron.d/rw-rs
fi

# configure ircd
if ! diff <(grep -v pass "$rwrs_root/etc/inspircd.conf") \
          <(grep -v pass /etc/inspircd/inspircd.conf) &>/dev/null
then
    cp -vf "$rwrs_root/etc/inspircd.conf" /etc/inspircd/inspircd.conf
    ircd_pass=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 24)
    sed -i "s/@ircdpasshere@/$ircd_pass/g" /etc/inspircd/inspircd.conf
    touch /etc/inspircd/inspircd.motd
    chown -R irc:irc /etc/inspircd/
    chmod 700 /etc/inspircd/
    chmod 600 /etc/inspircd/inspircd.conf
    systemctl restart inspircd
fi

# build apache
if [ ! -f $httpd_root/bin/httpd ]; then
    pushd ~
    wget "https://github.com/apache/httpd/archive/${httpd_version}.tar.gz"
    tar xf "${httpd_version}.tar.gz"
    pushd "httpd-${httpd_version}"
    svn co http://svn.apache.org/repos/asf/apr/apr/trunk srclib/apr
    ./buildconf
    ./configure --prefix=$httpd_root --with-included-apr --with-libxml2=/usr \
        --enable-mods-shared=all --enable-mpms-shared=all --enable-suexec \
        --enable-proxy --enable-cgi --enable-userdir
    make
    make install
    popd
    groupadd apache
    useradd -r -d $httpd_root -s /usr/sbin/nologin -g apache apache
    popd
fi

# configure apache
if ! diff "$rwrs_root/etc/httpd.service" /etc/systemd/system/httpd.service || \
   ! diff "$rwrs_root/etc/httpd.conf" $httpd_root/conf/httpd.conf
then
    cp -vf "$rwrs_root/etc/httpd.service" /etc/systemd/system/
    cp -vf "$rwrs_root/etc/httpd.conf" $httpd_root/conf/
    rm -rf $htdocs_root
    ln -s "$rwrs_root/htdocs" $htdocs_root
    systemctl daemon-reload
    systemctl enable httpd
    systemctl restart httpd
fi

# TODO tls ircd
# TODO tls httpd
# TODO alerting
