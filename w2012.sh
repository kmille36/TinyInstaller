#!/usr/bin/env sh
if [ "$(id -u)" != "0" ]; then
	echo "You must be root to execute the script. Exiting."
	exit 1
fi
rm ti.sh
wget https://github.com/4iTeam/TinyInstaller/raw/main/ti.sh
bash ti.sh https://bit.ly/32Pnh1S
