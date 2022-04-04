### Tests

1. Make a VirtualBox vm named `rwrs_debian` with ~16g disk, 4g RAM
2. Forward port 2222 on the host to port 22 on the vm
3. Install Debian in the vm (uncheck desktop env, check SSH server)
4. At a root shell, take a snapshot named `pristine_root_shell`
5. Now `./run_tests.sh` to run tests. (A patch from `git diff
   origin/master` is automatically applied to the repo in the vm.)
6. After tests pass, take another snapshot named
   `pristine_root_shell_bootstrapped` at a root shell.
7. Now you can run `./run_tests.sh -b` (faster)
