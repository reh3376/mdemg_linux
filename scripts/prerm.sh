#!/bin/sh
set -e

# Stop service for the invoking user (best-effort)
if [ -d /run/systemd/system ]; then
    systemctl stop "mdemg@${SUDO_USER:-$USER}" 2>/dev/null || true
    systemctl disable "mdemg@${SUDO_USER:-$USER}" 2>/dev/null || true
fi
