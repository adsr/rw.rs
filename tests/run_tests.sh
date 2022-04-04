#!/bin/bash
#
# Usage: ./run_tests.sh [options]
#
# Options:
#   -h      show this help
#   -b      use pre-bootstrapped state (faster)
#   -s      skip tests (bootstrap only)
#   -x      skip cleanup of temp files
#
set -eu

source "$(dirname $(cd $(dirname "${BASH_SOURCE[0]}") &>/dev/null && pwd))/bin/common.sh"
vm_name='rwrs_debian'
snapshot_name='pristine_root_shell'
rootkey_fname='rootkey'
testkey_fname='testkey'
patch_fname='patch'
test_user='testacct'
sshd_port=2222
sshd_host='localhost'
tmp_dir=$(mktemp -d /tmp/rwrs.XXXXXXXXXX)
skip_tests=0
current_test=''
test_count=0
fail_count=0
assert_count=0
no_cleanup=0

main() {
    trap on_exit EXIT
    while getopts ":hbsx" opt; do
        case $opt in
            h)  usage 0 ;;
            b)  snapshot_name='pristine_root_shell_bootstrapped' ;;
            s)  skip_tests=1 ;;
            x)  no_cleanup=1 ;;
            \?) usage 1 ;;
        esac
    done
    set -x
    pushd $tmp_dir
    restore_vm
    gen_patch
    checkout_and_patch
    bootstrap
    create_test_user
    [ "$skip_tests" -eq 0 ] && run_tests
    popd
}

usage() {
    local exit_code=${1:-0}
    tail -n+3 "${BASH_SOURCE[0]}" | awk '!/^#/{exit} {print}' | cut -c3-
    exit $exit_code
}

gen_patch() {
    info 'generating patch'
    git -C $rwrs_root diff origin/master >$patch_fname
}

checkout_and_patch() {
    info 'checking out repo and applying patch'
    root_cmd "DEBIAN_FRONTEND=noninteractive apt install -yq git"
    root_cmd "test -d $rwrs_dir || { cd /opt && git clone --recursive $repo_url rw.rs; }"
    root_cmd "git -C $rwrs_dir reset --hard"
    root_cmd "git -C $rwrs_dir clean -fdx"
    root_cmd "git -C $rwrs_dir pull --rebase --recurse-submodules"
    root_cmd "cd $rwrs_dir && patch -p1" <$patch_fname
    root_cmd "touch $rwrs_dir/$do_not_pull_fname"
}

bootstrap() {
    info 'running bootstrap'
    root_cmd "RWRS_TEST=1 $rwrs_dir/bin/bootstrap.sh"
}

create_test_user() {
    ssh-keygen -t ed25519 -N '' -f $testkey_fname
    root_cmd "mkdir -p $rwrs_dir/users/$test_user"
    root_cmd "cat >$rwrs_dir/users/$test_user/authorized_keys" <"${testkey_fname}.pub"
    root_cmd "$rwrs_dir/bin/create_users.sh"
    root_cmd "$rwrs_dir/bin/update_user_keys.sh"
    root_cmd "$rwrs_dir/bin/gen_user_proxy_conf.sh"
}

run_tests() {
    ntests=$(find "$rwrs_root/tests" -type f -name 'test_*.sh' | wc -l)
    for test in $(find "$rwrs_root/tests" -type f -name 'test_*.sh' | sort); do
        test_count=$((test_count+1))
        current_test=$(basename $test)
        source $test
    done
    pass_count=$((assert_count-fail_count))
    printf "%d/%d assertion(s) passed\n" $pass_count $assert_count
    if [ "$fail_count" -eq 0 ]; then
        info "tests passed"
    else
        err "tests failed"
        exit 1
    fi
}

assert() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-actual<$actual> expected<$expected>}"
    local log=''
    local result=''
    assert_count=$((assert_count+1))
    if [ "$actual" == "$expected" ]; then
        log='info'
        result='ok'
    else
        log='err'
        result='fail'
        fail_count=$((fail_count+1))
    fi
    $log "$(printf "[test:%2d/%-2d assert:%2d %20s] %4s: $msg" $test_count $ntests $assert_count $current_test $result)"
}

restore_vm() {
    # find vm uuid
    local vm_uuid=$(
        vboxmanage showvminfo --machinereadable $vm_name | \
        grep ^UUID= | \
        cut -d= -f2 | \
        cut -d'"' -f2 \
    )

    # check reqs
    if [ -z "$vm_uuid" ]; then
        die "could not find VirtualBox vm: $vm_name"
    fi
    if ! { vboxmanage snapshot $vm_name list | grep -q $snapshot_name; }; then
        die "could not find VirtualBox snapshot: $snapshot_name"
    fi

    # restore vm at pristine state
    info 'restoring vm'
    if { vboxmanage list runningvms | grep -q $vm_uuid; }; then
        # poweroff vm if running
        vboxmanage controlvm $vm_name poweroff
        sleep 1 # TODO avoids an error that happens by restarting too soon
    fi
    vboxmanage snapshot $vm_name restore $snapshot_name
    vboxmanage startvm $vm_name

    # make key-pair
    info 'setting up ssh keys'
    ssh-keygen -t ed25519 -N '' -f $rootkey_fname
    pubkey=$(cat "${rootkey_fname}.pub")
    send_break
    send_cmd "mkdir -p ~/.ssh"
    send_cmd "echo $pubkey >~/.ssh/authorized_keys"
    send_cmd "chmod -R 600 ~/.ssh"
    send_cmd "systemctl restart sshd"
    send_cmd "clear"
    send_cmd "exit"

    # now we are playing with power
    info 'testing ssh'
    if [ "hello" != "$(root_cmd 'echo hello')" ]; then
        die "ssh command did not succeed"
    fi
}

send_keys() {
    vboxmanage controlvm $vm_name keyboardputstring "$@"
}

send_enter() {
    vboxmanage controlvm $vm_name keyboardputscancode 1c 9c
}

send_cmd() {
    send_keys "$@"
    send_enter
}

send_break() {
    vboxmanage controlvm $vm_name keyboardputscancode 1d 2e ae 9d
}

root_cmd() {
     ssh -F/dev/null \
        -o StrictHostKeyChecking=no \
        -o GlobalKnownHostsFile=/dev/null \
        -o UserKnownHostsFile=/dev/null \
        -o PreferredAuthentications=publickey \
        -i $rootkey_fname \
        -p $sshd_port \
         "root@$sshd_host" \
         "$@"
}

test_cmd() {
     ssh -F/dev/null \
        -o StrictHostKeyChecking=no \
        -o GlobalKnownHostsFile=/dev/null \
        -o UserKnownHostsFile=/dev/null \
        -o PreferredAuthentications=publickey \
        -i $testkey_fname \
        -p $sshd_port \
         "$test_user@$sshd_host" \
         "$@"
}

info() {
    echo -e "\e[92m\xe2\x97\x8f ${@}\e[0m"
}

err() {
    echo -e "\e[91m\xe2\x97\x8f ${@}\e[0m" >&2
}

die() {
    err "$@"
    exit 1
}

on_exit() {
    [ "$no_cleanup" -eq 0 ] && rm -rf $tmp_dir
}

main "$@"
