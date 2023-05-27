#!/bin/bash
set -eux
source "$(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd)/common.sh"
log_ns='bootstrap.sh'

# set time
if [ -z "${RWRS_SKIP_SET_DATE+x}" ]; then
    date -s "$(wget -qSO- --max-redirect=0 google.com 2>&1 | grep Date: | cut -d' ' -f5-8)Z"
    logger -t $log_ns "set system time"
fi

# install packages
if [ -z "${RWRS_SKIP_APT+x}" ]; then
    if ! grep -q testing /etc/apt/sources.list; then
        echo 'deb http://ftp.us.debian.org/debian/ testing main'      >/etc/apt/sources.list
        echo 'deb-src http://ftp.us.debian.org/debian/ testing main' >>/etc/apt/sources.list
    fi
    apt-get -y --allow-releaseinfo-change update
    DEBIAN_FRONTEND=noninteractive \
    apt install -yq build-essential libtool libtool-bin sudo quota net-tools \
        curl git zsh vim emacs nano mle screen tmux irssi weechat \
        subversion libxml2-dev libpcre3-dev strace gdb socat sqlite3 \
        libsqlite3-dev fish mosh stow re2c bison libssl-dev pkg-config \
        zlib1g-dev libreadline-dev libgd-dev libfreetype6-dev libwebp-dev \
        libonig-dev lua5.3 liblua5.3-dev libffi-dev bind9-dnsutils cmake \
        ca-certificates debian-archive-keyring snapd rsync
    systemctl daemon-reexec
    logger -t $log_ns "ran apt updates"
fi

# configure swap
if ! grep -q $swap_path /proc/swaps; then
    dd if=/dev/zero of=$swap_path bs=1M count=2048
    mkswap $swap_path
    chmod 600 $swap_path
    swapon $swap_path
    logger -t $log_ns "created swap"
fi

# configure quota
if [ ! -f /aquota.user ]; then
    awk -vq=$quota_path \
        '{if($2==q){ $4=$4",usrjquota=aquota.user,jqfmt=vfsv1" } print}' \
        /etc/fstab >/etc/fstab.new
    mv -vf /etc/fstab.new /etc/fstab
    mount -vo remount $quota_path
    quotacheck -ucm $quota_path
    quotaon -v $quota_path
    logger -t $log_ns "created disk quota"
fi

# configure sshd
if ! diff "$rwrs_root/etc/sshd_config" /etc/ssh/sshd_config &>/dev/null; then
    cp -vf "$rwrs_root/etc/sshd_config" /etc/ssh/
    systemctl restart sshd
    logger -t $log_ns "updated sshd_config"
fi

# configure restricted user slice
$rwrs_root/bin/update_restricted_slice_conf.sh

# configure cron
if ! diff "$rwrs_root/etc/cron" /etc/cron.d/rw-rs &>/dev/null; then
    cp -vf "$rwrs_root/etc/cron" /etc/cron.d/rw-rs
    logger -t $log_ns "updated cron"
fi

# build apache
if ! { [ -f $httpd_root/bin/httpd ] && \
    [ "$($httpd_root/bin/httpd -v | grep -Po '(?<=Apache/)\d+\.\d+\.\d+')" \
    = "$httpd_version" ] ; }
then
    pushd ~
    wget -O httpd.tar.gz \
        "https://github.com/apache/httpd/archive/${httpd_version}.tar.gz"
    rm -rf "httpd-${httpd_version}"
    tar xf httpd.tar.gz
    pushd "httpd-${httpd_version}"
    svn co http://svn.apache.org/repos/asf/apr/apr/trunk srclib/apr
    ./buildconf
    CFLAGS='-I /usr/include/libxml2/' \
        ./configure --prefix=$httpd_root --with-included-apr --with-libxml2=/usr \
        --enable-mods-shared=all --enable-mpms-shared=all --enable-suexec \
        --enable-proxy --enable-cgi --enable-userdir --enable-debugger-mode \
        --enable-ssl
    make
    make install
    popd
    if ! getent passwd apache >/dev/null; then
        groupadd apache
        useradd -r -d $httpd_root -s /usr/sbin/nologin -g apache apache
    fi
    mkdir -p $httpd_var_dir
    chown apache:apache $httpd_var_dir
    popd
    logger -t $log_ns "installed httpd"
fi

# build php
if ! { command -v php && [ $(php -r 'echo PHP_VERSION;') = "$php_version" ]; }; then
    pushd ~
    wget -O php.tar.gz \
        "https://github.com/php/php-src/archive/php-${php_version}.tar.gz"
    rm -rf "php-src-php-${php_version}"
    tar xf php.tar.gz
    pushd "php-src-php-${php_version}"
    ./buildconf --force
    ./configure --enable-pcntl --enable-sockets --with-openssl --with-readline \
         --without-pear --with-zlib --enable-soap --enable-bcmath \
         --enable-mbstring --enable-opcache --enable-debug \
         --enable-gd --with-webp --with-jpeg --with-freetype \
         --with-apxs2=$httpd_root/bin/apxs --with-ffi --disable-session \
         --disable-fileinfo
    make
    make install
    popd
    popd
    logger -t $log_ns "installed php"
fi

# symlink php config
if [ ! -h "$php_ini_path" ]; then
    ln -sfv "$rwrs_root/etc/php.ini" $php_ini_path
    logger -t $log_ns "symlinked php_ini_path"
fi

# install ssl certs (not in test env)
if [ -z "${RWRS_TEST+x}" ]; then
    # install certbot
    if ! command -v certbot &>/dev/null; then
        snap install core
        snap refresh core
        snap install --classic certbot
        ln -sfv /snap/bin/certbot /usr/bin/certbot
    fi

    # request cert if not present or expired
    if [ ! -f /etc/ssl/private/rwrs_priv.pem ] || { certbot certificates | grep -q EXPIRED; }; then
        certbot certonly --non-interactive --manual \
            --agree-tos --email=rwrs@protonmail.com --domains=rw.rs \
            --manual-auth-hook=$rwrs_root/bin/certbot_hook.sh \
            --manual-cleanup-hook=$rwrs_root/bin/certbot_clean.sh
        ln -sfv /etc/letsencrypt/live/rw.rs/fullchain.pem /etc/ssl/certs/rwrs_chain.pem
        ln -sfv /etc/letsencrypt/live/rw.rs/privkey.pem   /etc/ssl/private/rwrs_priv.pem
        systemctl restart httpd
        logger -t $log_ns "updated ssl cert"
    fi
fi

# configure apache
if ! diff "$rwrs_root/etc/httpd.service" /etc/systemd/system/httpd.service || \
   ! diff "$rwrs_root/etc/httpd.conf" $httpd_root/conf/httpd.conf
then
    cp -vf "$rwrs_root/etc/httpd.service" /etc/systemd/system/
    cp -vf "$rwrs_root/etc/httpd.conf" $httpd_root/conf/
    rm -rf $htdocs_root
    ln -sfv "$rwrs_root/htdocs" $htdocs_root
    systemctl daemon-reload
    if systemctl is-active httpd; then
        systemctl reload httpd
    else
        systemctl enable httpd
        systemctl restart httpd
    fi
    logger -t $log_ns "updated httpd config"
fi

# symlink lib dir
if [ ! -h "$share_lib_dir" ]; then
    ln -sfv "$rwrs_root/lib" $share_lib_dir
    logger -t $log_ns "symlinked share_lib_dir"
fi

# allow users to invoke chsh without a password
if [ -f /etc/pam.d/chsh ]; then
    if ! grep -q '^auth sufficient pam_shells.so$' /etc/pam.d/chsh; then
        sed -i -r \
            's|^auth\s+required\s+pam_shells\.so$|auth sufficient pam_shells.so|g' \
            /etc/pam.d/chsh
        cat /etc/pam.d/chsh
        grep -q '^auth sufficient pam_shells.so$' /etc/pam.d/chsh
        logger -t $log_ns "updated /etc/pam.d/chsh"
    fi
else
    echo 'auth sufficient pam_shells.so' >/etc/pam.d/chsh
    logger -t $log_ns "wrote /etc/pam.d/chsh"
fi

# recompile crawdb
if [ "$(git -C $crawdb_dir rev-parse HEAD 2>/dev/null)" != \
     "$(cat $crawdb_dir/.build_hash 2>/dev/null)" ]
then
    pushd $crawdb_dir
    make clean all
    git rev-parse HEAD >"$crawdb_dir/.build_hash"
    popd
    logger -t $log_ns "recompiled crawdb"
fi

# make robot user
if ! id -u robot 2>/dev/null; then
    groupadd robot
    useradd -r -m -d /home/robot -s /bin/bash -g robot robot
    logger -t $log_ns "created robot user"
fi

# add robot sudoers entry
if ! [ -f /etc/sudoers.d/rwrs_robot ]; then
    echo 'robot ALL=(root:root) NOPASSWD: /opt/rw.rs/bin/robot_as_root.sh' \
        >/etc/sudoers.d/rwrs_robot
    logger -t $log_ns "created robot sudoer rule"
fi

# create mosh group
groupadd -f mosh

# install rwrs_mosh_server
if ! diff "$rwrs_root/bin/rwrs_mosh_server.sh" /usr/bin/rwrs_mosh_server &>/dev/null; then
    cp -vf "$rwrs_root/bin/rwrs_mosh_server.sh" /usr/bin/rwrs_mosh_server
    logger -t $log_ns "updated rwrs_mosh_server"
fi

# add mosh sudoers entry
if ! [ -f /etc/sudoers.d/mosh ]; then
    echo '%mosh ALL=(root:root) NOPASSWD: /usr/bin/rwrs_mosh_server ""' \
        >/etc/sudoers.d/mosh
    logger -t $log_ns "created mosh sudoer rule"
fi

# manually configured items:
#   /usr/httpd/conf/secrets.conf
#   /home/robot/.ssh
