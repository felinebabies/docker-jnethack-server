#!/bin/sh
set -eu

key_dir=/var/lib/jnethack/ssh
key_file=$key_dir/ssh_host_ed25519_key
install -d -m 0700 "$key_dir"
install -d -m 0755 /run/sshd

if [ ! -f "$key_file" ]; then
    ssh-keygen -q -t ed25519 -N '' -f "$key_file"
fi

exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config.jnethack
