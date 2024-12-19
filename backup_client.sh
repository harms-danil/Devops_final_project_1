#!/bin/bash

# Activate the option that interrupts script execution if any command terminates with a non-zero status
set -e

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
		if [ ! -d /usr/local/etc/urbackup ]; then
			echo -e "\n====================\nUrBackup Client could not be found\nInstalling...\n====================\n"
			# Install UrBackup Client
			TF=$(mktemp) && wget "https://hndl.urbackup.org/Client/2.5.25/UrBackup%20Client%20Linux%202.5.25.sh" -O "$TF" && sh "$TF";
			rm -f "$TF"
		else
			echo -e "\n====================\nUrBackup Client found!!!\nreInstalling...\n====================\n"
			while true; do
				read -r -n 1 -p $'\n'"Are you ready to reinstall UrBackup? (y|n) " yn
				case $yn in
				[Yy]*)
					uninstall_urbackupclient
					TF=$(mktemp) && wget "https://hndl.urbackup.org/Client/2.5.25/UrBackup%20Client%20Linux%202.5.25.sh" -O "$TF" && sh
					"$TF"; rm -f "$TF"
					echo -e "\nDONE\n"
					break
					;;
				[Nn]*)
					break
					;;
				*) echo -e "\nPlease answer Y or N!\n" ;;
				esac
			done
		fi
		break
		;;
	[Nn]*)
		echo -e "\n"
		break
		;;
	*) echo -e "\nPlease answer Y or N!\n" ;;
	esac
done

# install dattobd
echo -e "\n====================\nInstalling dattobd\n====================\n"
while true; do
	read -r -n 1 -p $'\n'"Are you ready to install dattobd? (y|n) " yn
	case $yn in
	[Yy]*)
		if [ ! -d /usr/src/dattobd-0.11.8/dattobd.h ]; then
			echo -e "\n====================\nUrBackup dattodb not be found\nInstalling...\n====================\n"
			apt-key adv --fetch-keys https://cpkg.datto.com/DATTO-PKGS-GPG-KEY
			echo "deb [arch=amd64] https://cpkg.datto.com/datto-deb/public/$(lsb_release -sc) $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/datto-linux-agent.list
			apt update -y
			apt install dattobd-dkms dattobd-utils
		else
			echo -e "Dattobd already installing!!!"
		fi
		break
		;;
	[Nn]*)
		echo -e "\n"
		break
		;;
	*) echo -e "\nPlease answer Y or N!\n" ;;
	esac
done

# Setting urbackup client config file
echo -e "\n====================\nSetting urbackup client config file \n====================\n"
if ! grep -Fxq "INTERNET_ONLY=false" /etc/default/urbackupclient &>/dev/null; then
	sed -r -i 's/(^INTERNET_ONLY=\s).*$/\1'"false"'/' /etc/default/urbackupclient
	echo "\nDONE"
fi

# Add folder for backup
echo -e "\n====================\nAdd folder for backup \n====================\n"
while true; do
	read -r -n 1 -p $'\n\n'"Add new path for backup? (y|n) " yn
		case $yn in
		[Yy]*)
			read -r -p $'\n'"Enter path for backup files: " file_path
			urbackupclientctl add-backupdir -d "$file_path"
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
# setting iptables for client
iptables_add INPUT -p tcp --dport 35621 -j ACCEPT -m comment --comment 'urbackup Sending files during file backups (file server)'
iptables_add INPUT -p udp --dport 35622 -j ACCEPT -m comment --comment 'urbackup UDP broadcasts for discovery'
iptables_add INPUT -p tcp --dport 35623 -j ACCEPT -m comment --comment 'urbackup Commands and image backups'

echo -e "\n====================\nSaving iptables config \n====================\n"
service netfilter-persistent save
iptables -L -n -v --line-number
echo -e "\nDONE\n"

exit 0