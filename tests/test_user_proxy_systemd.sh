#!/bin/bash

php_script=$(cat <<'EOD'
#!/usr/bin/env php
<?php
require '/usr/share/lib/php/http.php';
http_handle(function() {
    echo 'hello_via_systemd_and_php';
});
EOD
)

php_script_b64=$(echo "$php_script" | base64 -w0)

cmd=''
cmd+='mkdir -p ~/public_html; '
cmd+="echo $php_script_b64 | base64 -d >proxy; "
cmd+="chmod +x proxy; "
cmd+='systemctl --user daemon-reload; '
cmd+='systemctl --user start proxy; '
cmd+="sleep 1; curl -m5 -s localhost/~$test_user/proxy/test; wait"

assert 'hello_via_systemd_and_php' \
    "$(test_cmd "$cmd")" \
    'user proxypass via user systemd and php should work'
