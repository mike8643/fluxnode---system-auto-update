#!/bin/bash

# Configuration
queuehours=48
maintenanceminutes=20

# Get the current timestamp
timestamp=$(date +"%Y-%m-%d %T")

# Get the node information
node=$(/usr/local/bin/flux-cli getinfo)
nodestatus=$(/usr/local/bin/flux-cli getzelnodestatus) # added for check for confirmed status
nodelist=$(/usr/local/bin/flux-cli viewdeterministiczelnodelist)
nodecount=$(/usr/local/bin/flux-cli getzelnodecount)

# Check if flux-cli command is successful
if [ $? -ne 0 ]; then
    echo "$timestamp Error: flux-cli command failed"
    exit 1
fi

# Extract the ip address
ipaddy=$(echo $nodestatus | jq '.ip' -r)
if [ -z $ipaddy ]; then
	echo "IP not found in status"
	ipaddy=1.2.3.4
fi

# Extract the rank
noderank=$(echo $nodelist | jq '.[] | select(.ip=='\"$ipaddy\"') | .rank')
if [ -z $noderank ]; then
	echo "Node not found in list"
	noderank=999999
fi
# Extract the node tier
nodetier=$(echo $nodestatus | jq '.tier' -r)

# Extract the number of nodes in tier
case $nodetier in 
	CUMULUS) 
		tierhigh=$(echo $nodecount | jq '."cumulus-enabled"' -r);; 
	NIMBUS) 
		tierhigh=$(echo $nodecount | jq '."nimbus-enabled"' -r);; 
	STRATUS) 
		tierhigh=$(echo $nodecount | jq '."stratus-enabled"' -r);; 
esac

# Calculate queue window
queuewindow=$(($tierhigh-($queuehours*30)))

# Extract the status from the node information
status=$(echo $nodestatus | jq '.status' -r) # changed node to nodestatus

# Extract the version from the node information
ver=$(echo $node | jq '.version' -r)

# Check if the version exists
if [ -z $ver ]; then
    # If version does not exist, exit the script
    echo "$timestamp Error: version not found"
    exit 1
else
    # Get the blockchain information
    blockchain=$(curl https://api.runonflux.io/daemon/getblockcount)

    # Check if curl command is successful
    if [ $? -ne 0 ]; then
        echo "$timestamp Error: curl command failed"
        exit 1
    fi 

    # Extract the current height from the blockchain information
    current_height=$(echo $blockchain | jq '.data' -r)

    # Extract the confirmed height from the node information
    confirmed_height=$(echo $nodestatus | jq '.last_confirmed_height' -r) # changed node to nodestatus

    # Calculate the number of blocks in maintenance
    maintanance_blocks=$(($current_height - $confirmed_height))

    # Calculate the number of blocks until maintenance
    maintanace=$((120 - $maintanance_blocks))

	# Update the package list
	sudo apt-get update -qq -y
	# Check for updates
	updates=$(apt list --upgradable 2>/dev/null | wc -l)
	# Check for github update
	cd $HOME/zelflux
	git fetch
	current_ver=$(jq -r '.version' $HOME/zelflux/package.json)
	check_ver=$(curl -s https://raw.githubusercontent.com/RunOnFlux/flux/master/package.json | jq -r '.version')
	if [ "$current_ver" != "$check_ver" ]; then
		echo "Found Changes to FluxOS, Current Version $current_ver , Found Version $check_ver"
		gittest=1
	else
		echo "No Changes to FluxOS"
		gittest=0
	fi


    # If no updates are available
    if [ $updates -eq 1 ] && [ $gittest -eq 0 ]; then
        # Print a message and exit the script
        echo "$timestamp No updates available."
        exit 0
    else
        
		# Within queue window check
		if [ $noderank -ge $queuewindow ]; then
			# Within maintenance window, Gate #2
			if [ $maintanace -le $maintenanceminutes ]; then
				delay=$(((maintanace*2)+90))
				delayed=$(((maintanace*120)+4800))
			else
				delay=0
				delayed=0
			fi

			# Found Changes in github?
			if [ $gittest -eq 1 ]; then
				# Upgrade the packages and FluxOS
				echo "FluxOS update delayed due to maintenance window after $delay minutes"
				sleep $delayed 
				echo "$timestamp Packages and FluxOS being upgraded"
				sudo apt-get update -y && sudo apt-get --with-new-pkgs upgrade -y && sudo apt autoremove -y && cd $HOME/zelflux && git checkout . && git checkout master && git reset --hard origin/master && git pull && sudo reboot
			fi
		
			if [ $updates -ne 1 ]; then
				# Upgrade just the packages
				sudo apt-get update -y && sudo apt-get --with-new-pkgs upgrade -y && sudo apt autoremove -y				
				echo "$timestamp Packages Upgraded"
			fi
			# Check if a reboot is required
			if systemctl list-jobs --no-legend --full --all | grep 'reboot.target' ; then
				# Check if node CONFIRMED
				if [ $status != "CONFIRMED" ]; then
					echo "$timestamp Reboot..."
					sudo reboot
				else
					if [ $maintanace -le $maintenanceminutes ]; then
						#Schedule reboot after delay
						echo "$timestamp Scheduling reboot after $delay minutes"
						sudo shutdown -r +$delay
					else
						echo "$timestamp Reboot..."
						sudo reboot
					fi
				fi
			else
				# If reboot is not required, exit the script
				echo "$timestamp No reboot required"
				exit 0
			fi		
		else
			echo "$timestamp Not in window, Currently Rank $noderank"
		fi
	fi
fi
