Edit file **HyperBackup** and enter **nocompress** for HyperBackup logs:

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
    #added
    nocompress
    #added
    postrotate
        /usr/syno/bin/synosystemctl reload syslog-ng || true
    endscript
}
```

**Note:** This has to be done after every DSM or Hyper Backup update.
