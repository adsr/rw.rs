#!/bin/bash

php_script=$(cat <<'EOD'
<?php
require '/usr/share/lib/php/http.php';
http_handle(function() {
    echo 'hello_from_php';
});
EOD
)

php_script_b64=$(echo "$php_script" | base64 -w0)

cmd=''
cmd+='mkdir -p ~/public_html; '
cmd+="echo $php_script_b64 | base64 -d >serve.php; "
cmd+='timeout 5 socat '
cmd+="UNIX-LISTEN:/home/$test_user/public_html/proxy.sock,fork,perm-early=0666 "
cmd+="SYSTEM:'php /home/$test_user/serve.php' &>/dev/null & "
cmd+="sleep 1; curl -m5 -s localhost/~$test_user/proxy/test; wait"

assert 'hello_from_php' \
    "$(test_cmd "$cmd")" \
    'user proxypass via php should work'
