# Fluxnode---system-auto-update
## Forked Auto update system for Flux node operators

Simple bash script to update server OS, FluxOS and postpone reboot (if needed after updates) if node is not in maintenance window or queue window
Using *Crontab* for autoupdates

## How it works:

It gets the node information using the `flux-cli` getinfo command, which is used to check if the node is running

It calculates the number of blocks for maintenance window

It calculates the node queue window based on the current rank compared to highest rank in tier. 2 days from highest rank

It updates the package list using the `sudo apt update` command and then checks for available updates using the apt list --upgradable command

If updates are available, it upgrades the packages using the `sudo apt upgrade -y` command

It checks if a reboot is required 

If a reboot is required, it checks if the node status is "CONFIRMED" and if the maintenance window is open (i.e. if the number of blocks until maintenance is less than or equal to 20) and if so, it schedules a reboot after a delay of 20 minutes plus the number of minutes until maintenance 

If a reboot is not required, it exits the script

It updates the FluxOS node software pulling from the official repo using command cd $HOME/zelflux && git checkout . && git checkout master && git reset --hard origin/master && git pull

## How to use:

Login to the server with the same user as the node (`home` directory where the flux node is installed) using   `ssh` 

download the script 
```
wget https://github.com/mike8643/fluxnode---system-auto-update/releases/download/v1.0.0/autoupdate_system.sh
```

copy and paste command below to set the `exec` permission to the script , create `log` file and setup *crontab*
```
chmod +x autoupdate_system.sh && mkdir crontab_logs && touch crontab_logs/autouptade_os.log && crontab -l | sed "\$a0 23 */1 * * /home/$USER/autoupdate_system.sh >> /home/$USER/crontab_logs/autouptade_os.log 2>&1" | crontab -
```

the *Crontab* is set to execute script everyday at 6pm EST (2300 UTC)

Logs directory `/home/$USER/crontab_logs/autouptade_os.log`


   


