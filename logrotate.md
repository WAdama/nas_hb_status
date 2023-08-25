Logon to DSM via SSH

Change to "/usr/local/etc/logrotate.d"

Edit file HyperBackup and enter "nocompress" for HyperBackup logs:

```
/var/log/synohbkpvfs.log {
    missingok
    postrotate
        /usr/syno/bin/synosystemctl reload syslog-ng || true
    endscript
}

/var/packages/HyperBackup/var/log/*.log {
    missingok
    **nocompress**
    postrotate
        /usr/syno/bin/synosystemctl reload syslog-ng || true
    endscript
}
```
