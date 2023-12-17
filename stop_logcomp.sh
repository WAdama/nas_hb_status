#!/bin/bash
# Version 1.0

if ! grep -q "nocompress" /usr/local/etc/logrotate.d/HyperBackup
then
    sed -i -z 's/missingok/missingok\n\t#added\n\tnocompress\n\t#added/2' /usr/local/etc/logrotate.d/HyperBackup
fi
if find /volume1/@appdata/HyperBackup/log/hyperbackup*.xz > /dev/null 2>&1
then
    unxz -q /volume1/@appdata/HyperBackup/log/hyperbackup*.xz
fi
