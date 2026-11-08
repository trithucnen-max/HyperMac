#!/bin/bash
set -e
SRC_SMC="$1"
SRC_HELPER="$2"

if [ -z "$SRC_SMC" ] || [ -z "$SRC_HELPER" ]; then
    echo "Error: Missing source paths"
    exit 1
fi

mkdir -p /usr/local/bin
cp -f "$SRC_SMC" /usr/local/bin/displaycontrol-smc
chmod 755 /usr/local/bin/displaycontrol-smc
chown root:wheel /usr/local/bin/displaycontrol-smc 2>/dev/null || true

cp -f "$SRC_HELPER" /usr/local/bin/displaycontrol-power
chmod 755 /usr/local/bin/displaycontrol-power
chown root:wheel /usr/local/bin/displaycontrol-power 2>/dev/null || true

mkdir -p /etc/sudoers.d
echo "ALL ALL = (ALL) NOPASSWD: /usr/local/bin/displaycontrol-power" > /etc/sudoers.d/displaycontrol_power
chmod 440 /etc/sudoers.d/displaycontrol_power
chown root:wheel /etc/sudoers.d/displaycontrol_power 2>/dev/null || true

echo "SUCCESS"
