Edit file HyperBackup and enter "nocompress" for HyperBackup logs:

vi /usr/local/etc/logrotate.d/HyperBackup

```
/var/log/synohbkpvfs.log {
    missingok
    postrotate
        /usr/syno/bin/synosystemctl reload syslog-ng || true
    endscript
}

/var/packages/HyperBackup/var/log/*.log {
    missingok
    #prohibit compression of HyperBackup logs:
    nocompress
    postrotate
        /usr/syno/bin/synosystemctl reload syslog-ng || true
    endscript
}
```
