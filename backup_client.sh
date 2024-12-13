#!/bin/bash

# Activate the option that interrupts script execution if any command terminates with a non-zero status
set -e

# Vars
backup_dir="/backup"

# Check if the script is running from the root user
if [[ "${UID}" -ne 0 ]]; then
    echo -e "You need to run this script as root!"
    exit 1
fi

# Function that checks for the presence of a rule in iptables and, if missing, applies it
iptables_add() {
    if ! iptables -C "$@" &>/dev/null; then
        iptables -A "$@"
    fi
}

# Installing UrBackup client
echo -e "\n====================\nInstalling UrBackup client \n====================\n"
while true; do
    read -r -n 1 -p $'\n'"Are you ready to install UrBackup client? (y|n) " yn
	case $yn in
	[Yy]*)
		# Add repository UrBackup server and update
		TF=$(mktemp) && wget "https://hndl.urbackup.org/Client/2.5.25/UrBackup%20Client%20Linux%202.5.25.sh" -O "$TF" && sudo sh "$TF";
		rm -f "$TF"

		apt-key adv --fetch-keys https://cpkg.datto.com/DATTO-PKGS-GPG-KEY
		echo "deb [arch=amd64] https://cpkg.datto.com/datto-deb/public/$(lsb_release -sc) $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/datto-linux-agent.list
		apt update -y
		apt install dattobd-dkms dattobd-utils
		break
		;;
	[Nn]*)
		echo -e "\n"
		break
		;;
	*) echo -e "\nPlease answer Y or N!\n" ;;
	esac
done

# Set up iptables
echo -e "\n====================\nIptables configuration \n====================\n"
set -x
# setting iptables for client
iptables_add INPUT -p tcp --dport 35621 -j ACCEPT -m comment --comment 'urbackup Sending files during file backups (file server)'
iptables_add INPUT -p tcp --dport 35622 -j ACCEPT -m comment --comment 'urbackup UDP broadcasts for discovery'
iptables_add INPUT -p tcp --dport 35623 -j ACCEPT -m comment --comment 'urbackup Commands and image backups'

#iptables_add INPUT -p tcp --dport 55414 -j ACCEPT -m comment --comment 'urbackup FastCGI for web interface'
#iptables_add INPUT -p tcp --dport 55414 -j ACCEPT -m comment --comment 'urbackup HTTP web interface'
#iptables_add INPUT -p tcp --dport 55415 -j ACCEPT -m comment --comment 'urbackup Internet clients'
#iptables_add OUTPUT -p udp --dport 35623 -j ACCEPT -m comment --comment 'urbackup UDP broadcasts for discovery'
#iptables_add INPUT -j REJECT --reject-with icmp-host-prohibited
#iptables_add FORWARD -j REJECT --reject-with icmp-host-prohibited
echo -e "\n====================\nSaving iptables config \n====================\n"
service netfilter-persistent save
iptables -L -n -v
echo -e "\nDONE\n"

# Restart UrBackup service
#echo -e "\n====================\nRestart UrBackup service \n====================\n"
#
#systemctl daemon-reload
#systemctl restart urbackupsrv

exit 0