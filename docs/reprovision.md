### Notes for reprovisioning rw.rs

* On old host...
* `wall` notice about temporary maintenance
* Add `AllowUsers root adsr` to /etc/ssh/sshd_config and reload sshd
* Kill any logged in sessions
* `cd / && tar cf home.tar home`
* `cd /etc && tar cf letsencrypt.tar letsencrypt`
* Provision new host...
* Login as root
* Copy over `home.tar` and `letsencrypt.tar`
* Convert to Debian testing (`/etc/apt/sources.list`)
* `apt update`, `upgrade`, `dist-upgrade`
* Reboot for kernel
* `apt install -y git`
* `cd /opt && git clone --recursive https://github.com/adsr/rw.rs.git`
* `cd /etc && tar xf letsencrypt.tar`
* `/opt/rw.rs/bin/bootstrap.sh` # Takes a while
* `cd / && tar xf home.tar`
* `for u in $(ls -1 /home); do chown -R $u:$u /home/$u; done` # Fix uids
* `for u in $(ls -1 /home); do test "$u" = $(stat -c %U "/home/$u/.ssh") || echo "bad $u"; done` # Sanity check uids
* On local computer, add `/etc/hosts` entry for rw.rs to new IP
* Ensure site works. Debug if needed.
* Change DNS
* Decomm old host
* Ensure crons are running
* Make note on calendar near next cert expiration
