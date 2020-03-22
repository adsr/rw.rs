# rw.rs

An experimental software community with a 199X aesthetic.

To join, submit a pull request with your public key at `users/<you>/authorized_keys`.

### Quickstart

    $ # Fork rw.rs repo on GitHub
    $ git clone https://github.com/<you>/rw.rs.git
    $ cd rw.rs
    $
    $ # Generate key pair
    $ ssh-keygen -f ~/.ssh/id_rsa_rwrs
    $
    $ # Add pub key to repo
    $ mkdir users/<you>
    $ cp ~/.ssh/id_rsa_rwrs.pub users/<you>/authorized_keys
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
    $ # SHA256:UqnBpin2WJqzWNMisueYH6sVIft5GYkXVpa7WwP44m8
    $ # MD5:dc:49:95:99:e4:cf:a9:87:ac:37:f4:f5:8b:bd:5e:89
    $ ssh -i ~/.ssh/id_rsa_rwrs <you>@rw.rs
    $
    $ # Set your motd
    $ echo hello users >~/motd
    $
    $ # Make your web page at http://rw.rs/~<you>
    $ mkdir ~/public_html
    $ echo hello internet >~/public_html/index.html
    $
    $ # Idle in local ircd
    $ # Submit PRs to `README.md`, `bin/`, `etc/`, `htdocs/`, etc
    $ # Have fun
