#!/bin/sh
set -e

if [ "$1" = "purge" ]; then
    # Only on purge (dpkg --purge), remove shared data
    rm -rf /usr/share/mdemg 2>/dev/null || true
fi

if [ -d /run/systemd/system ]; then
    systemctl daemon-reload || true
fi
