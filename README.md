# rw.rs

Submit a pull request with your public key at `users/<you>/authorized_keys`.
Then come play.

### Quickstart

    you@local $ # Fork rw.rs repo on GitHub
    you@local $ git clone https://github.com/<you>/rw.rs.git
    you@local $ cd rw.rs
    you@local $
    you@local $ # Generate key pair
    you@local $ ssh-keygen -f ~/.ssh/id_rsa_rwrs
    you@local $
    you@local $ # Add pub key to repo
    you@local $ mkdir users/<you>
    you@local $ cp ~/.ssh/id_rsa_rwrs.pub users/<you>/authorized_keys
    you@local $ git add users/<you>/authorized_keys
    you@local $ git commit -m 'add user <you>'
    you@local $ git push
    you@local $
    you@local $ # Visit https://github.com/<you>/rw.rs.git
    you@local $ # Create pull request and wait until merged
    you@local $ # ...
    you@local $
    you@local $ # After ~10 minutes, account is auto-created
    you@local $ # Login!
    you@local $ ssh -i ~/.ssh/id_rsa_rwrs <you>@rw.rs
    you@rw.rs $
    you@rw.rs $ # Set your motd
    you@rw.rs $ echo hello users >~/motd
    you@rw.rs $
    you@rw.rs $ # Make your web page at http://rw.rs/~<you>
    you@rw.rs $ mkdir ~/public_html
    you@rw.rs $ echo hello internet >~/public_html/index.html
    you@rw.rs $
    you@rw.rs $ # Idle in local ircd
    you@rw.rs $
    you@rw.rs $ # Submit PRs to `README.md`, `bin/`, `etc/`, `htdocs/`, etc
    you@rw.rs $
    you@rw.rs $ # Have fun
