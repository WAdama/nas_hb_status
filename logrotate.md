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

I've also created a little script, which change the config file automatically and unzips already zipped log files: 

```
https://raw.githubusercontent.com/WAdama/nas_hb_status/master/stop_logcomp.sh
```
