#!/bin/sh
set -eu

if [ -n "${SSH_ORIGINAL_COMMAND:-}" ] || [ ! -t 0 ] || [ ! -t 1 ]; then
    echo 'Connect interactively with ssh -t nethack@HOST.' >&2
    exit 1
fi

export LANG=ja_JP.UTF-8
ulimit -t 120
exec /usr/bin/sudo -n -- /usr/local/libexec/dgamelaunch
