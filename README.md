# nas_hb_status

Bash script for PRTG by Paessler to monitoring status of backups with Synology's Hyper Backup

The sensor will show the status of the backups and the time passed since the last backup.

Sensor has to be created in PRTG on your Synology device.

Sensor tested on DS 918+ with DSM 6.2.3-25426 and Hyper Backup 2.2.4-1213 

### Prerequisites

Be sure you have set correct logon values for SSH in your device.

I personally use "Login via private key" with an user especially for monitoring which also may use sudo for this script without a password.

![Screenshot1](https://github.com/WAdama/nas_hb_status/blob/master/images/ssh_settings.png)

**HINT:** Since DSM 6.2.2 for SSH access the user has to be member of the local Administrators group on your Synology NAS.

### Installing

Place the script to /var/prtg/scriptsxml on your Synology NAS and make it executable. (You may have to create this directory structure because PRTG expects the script here.)

```
wget https://raw.githubusercontent.com/WAdama/nas_hb_status/master/nas_hb_status.sh
chmod +x nas_hb_status.sh
```

On your PRTG system place the file prtg.standardlookups.nas.hbstatus.ovl in *INSTALLDIR\PRTG Network Monitor\lookups\custom* and refresh it under **System Administration / Administrative Tools**

In PRTG create under your device which represents your Synology a SSH custom advanced senor.

Choose under "Script" this script and enter under "Parameters" the name and path of your configuration file.

![Screenshot1](https://github.com/WAdama/nas_hb_status/blob/master/images/nas_hb_status.png)

For the sensor create a conf file in your Synology's file system.

The configuration file must contain the following entry according to your backup tasks:

```
TASKS=("Backup - No1" "Backup - No2" "Backup - No3")
```
This script will set default values for limits in the Passed time channel:

Upper warning limit: 36 h (129600 s)

Upper error limit: 60 h (216000 s)

![Screenshot1](https://github.com/WAdama/nas_hb_status/blob/master/images/nas_hb_status_sensor.png)
