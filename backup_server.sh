#!/bin/bash

# Activate the option that interrupts script execution if any command terminates with a non-zero status
set -e

# Vars
dest_dir="/home/harms"
domain_name="backup.harms-devops.ru"

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

# Create new partition
echo -e "\n====================\nCreate new partition\n====================\n"
while true; do
	read -r -n 1 -p $'\n'"Are you ready to create new partition? (y|n) " yn
	case $yn in
	[Yy]*)
		df -h
		read -r -p $'\n'"Enter name to disk (format: /dev/sda1)" dev_disk
		sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${dev_disk}
  n # new partition
  p # primary partition
  1 # partition number 1
    # default - start at beginning of disk
    # default, extend partition to end of disk
  w # write the partition table
  q # and we're done
EOF
		break
		;;
	[Nn]*)
		break
		;;
	*) echo -e "\nPlease answer Y or N!\n" ;;
    esac
done


# Mounting BTRFS in /backup
echo -e "\n====================\nMounting a BTRFS format partition \n====================\n"
mkdir /backup
UUID=$(blkid -s UUID -o value -t TYPE=btrfs)
if ! grep -Fxq "UUID=$UUID /backup btrfs defaults 0 0" /etc/fstab &>/dev/null; then
          echo "UUID=$UUID /backup btrfs defaults 0 0" >>/etc/fstab
          echo -e "\nString 'echo "UUID=$UUID /backup btrfs defaults 0 0" >> /etc/fstab' added to /etc/fstab\n\n"
fi

# Add repository UrBackup server and update
add-apt-repository ppa:uroni/urbackup
apt update -y

# Check if the program is installed UrBackup
if [ ! -d /etc/urbackup/ ]; then
    echo -e "\n====================\nUrBackup could not be found\nInstalling...\n====================\n"
    systemctl restart systemd-timesyncd.service
	apt install urbackup-server -y
    echo -e "\nDONE\n"
else
    while true; do
        read -r -n 1 -p $'\n'"Are you ready to reinstall UrBackup? (y|n) " yn
        case $yn in
        [Yy]*)
            systemctl stop urbackupsrv
            systemctl disable urbackupsrv
            systemctl restart systemd-timesyncd.service
            apt purge -y urbackup-server
            apt install urbackup-server -y
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

# Set up iptables
echo -e "\n====================\nIptables configuration \n====================\n"
iptables_add INPUT -p tcp --dport 55414 -j ACCEPT -m comment --comment urbackup
iptables_add INPUT -j REJECT --reject-with icmp-host-prohibited
iptables_add FORWARD -j REJECT --reject-with icmp-host-prohibited
echo -e "\n====================\nSaving iptables config \n====================\n"
service netfilter-persistent save
echo -e "\nDONE\n"

# Restart UrBackup service
systemctl daemon-reload
systemctl restart urbackupsrv
systemctl enable urbackupsrv