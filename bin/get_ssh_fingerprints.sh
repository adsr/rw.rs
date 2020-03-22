#!/bin/sh
set -eu

for PUBKEY in /etc/ssh/*.pub; do
	ssh-keygen -l -f "$PUBKEY" | awk -v OFS='\t' '{ print $2, $4 }'
	ssh-keygen -l -f "$PUBKEY" -E md5 | awk -v OFS='\t' '{ print $2, $4 }'
done
