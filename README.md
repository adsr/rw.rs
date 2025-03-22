# rw.rs

An experimental software community with a 199X aesthetic.

To join, submit a pull request with your public key at `users/<you>/authorized_keys`[^1].

### Quickstart

    $ # Fork rw.rs repo on GitHub
    $ git clone https://github.com/<you>/rw.rs.git
    $ cd rw.rs
    $
    $ # Generate key pair (or use an existing key)
    $ ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_rwrs
    $
    $ # Add pub key to repo
    $ mkdir users/<you>     # Note: <you> should be <= 10 chars
    $ cp ~/.ssh/id_ed25519_rwrs.pub users/<you>/authorized_keys
    $ git add users/<you>/authorized_keys
    $ git commit -m 'add user <you>'
    $ git push
    $
    $ # Visit https://github.com/<you>/rw.rs.git
    $ # Create pull request and wait until merged
    $ # ...
    $
    $ # After ~10 minutes, account is auto-created
    $ # Login!
    $ ssh -i ~/.ssh/id_ed25519_rwrs <you>@rw.rs
    $
    $ # Set your motd
    $ echo hello users >~/motd
    $
    $ # Make your web page at http://rw.rs/~<you>
    $ mkdir ~/public_html
    $ echo hello internet >~/public_html/index.html
    $
    $ # Idle in tilde.chat IRC
    $ # Want a new feature? Feel free to submit PRs
    $ # Enjoy

### CGI-like setup

In quasi-nostalgic fashion, rw.rs also supports CGI-like web apps if you want
to go beyond static HTML. Below is an example of a CGI-like PHP app, but you
can use whatever language you wish.

    adsr@rwrs:~$ cat ~/.config/systemd/user/proxy.service
    [Service]
    ExecStart=/bin/bash -c 'socat UNIX-LISTEN:$HOME/public_html/proxy.sock,fork,perm-early=0666 "SYSTEM:timeout 2 $HOME/proxy"'

    [Install]
    WantedBy=default.target
    adsr@rwrs:~$ ls -l ~/proxy
    -rwxr-xr-x 1 adsr adsr 229 Dec 23 22:51 /home/adsr/proxy
    adsr@rwrs:~$ cat proxy
    #!/usr/bin/env php
    <?php

    require '/usr/share/lib/php/http.php';

    http_handle(function($request, $set_code_fn, $set_header_fn) {
        $set_code_fn(200);
        $set_header_fn('Content-Type', 'text/plain');
        print_r($request);
    });
    adsr@rwrs:~$ systemctl --user daemon-reload
    adsr@rwrs:~$ systemctl --user start proxy
    adsr@rwrs:~$ systemctl --user status proxy
    ● proxy.service
       Loaded: loaded (/home/adsr/.config/systemd/user/proxy.service; enabled; vendor preset: enabled)
       Active: active (running) since Wed 2020-12-23 22:56:46 UTC; 2s ago
     Main PID: 29686 (socat)
       CGroup: /user.slice/user-1000.slice/user@1000.service/proxy.service
               └─29686 socat UNIX-LISTEN:/home/adsr/public_html/proxy.sock,fork,perm-early=0666 SYSTEM:timeout 2 /home/adsr/proxy
    adsr@rwrs:~$ curl -s 'localhost/~adsr/proxy/test'
    Array
    (
        [headers] => Array
            (
                [host] => adsr
                [user-agent] => curl/7.68.0
                [accept] => */*
                [x-forwarded-for] => ::1
                [x-forwarded-host] => localhost
                [x-forwarded-server] => default
                [connection] => Keep-Alive
            )

        [content] =>
        [verb] => GET
        [uri] => /~adsr/proxy/test
        [protocol] => HTTP/1.1
        [uri_parts] => Array
            (
                [path] => /~adsr/proxy/test
            )

        [params] => Array
            (
            )

    )
    adsr@rwrs:~$ curl -s -X POST -d 'param=1' 'localhost/~adsr/proxy/test'
    Array
    (
        [headers] => Array
            (
                [host] => adsr
                [user-agent] => curl/7.68.0
                [accept] => */*
                [content-type] => application/x-www-form-urlencoded
                [x-forwarded-for] => ::1
                [x-forwarded-host] => localhost
                [x-forwarded-server] => default
                [content-length] => 7
                [connection] => Keep-Alive
            )

        [content] => param=1
        [verb] => POST
        [uri] => /~adsr/proxy/test
        [protocol] => HTTP/1.1
        [uri_parts] => Array
            (
                [path] => /~adsr/proxy/test
            )

        [params] => Array
            (
                [param] => 1
            )

    )

[^1]: Due to abuse, only GitHub accounts with some sort of legit activity will
      be accepted. If you don't have any GitHub activity, please link _to_ your
      GitHub account _from_ some other established identity (e.g., another
      tilde host, GitLab, a personal web site, etc.) and make a note of such in
      your PR. For genuine beginners with no established identity, or people
      wishing to preserve anonymity, I apologize. Unfortunately scammers have
      used this service for spam and other crap, which has almost resulted in
      the hosting provider terminating us.
