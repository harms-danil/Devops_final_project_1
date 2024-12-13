#!/bin/bash

# Activate the option that interrupts script execution if any command terminates with a non-zero status
set -e

# Vars
dest_dir="/home/harms"
domain_name="backup.harms-devops.ru"
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

create_disk_partition() {
	sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk "$1"
  n # new partition
  p # primary partition
  1 # partition number 1
    # default - start at beginning of disk
    # default, extend partition to end of disk
  t # recognize specified partition table type only
  83 # linux
  w # write the partition table
EOF
	device_disk=$(fdisk -l | grep "$size_disk"G | awk '{print $1}')
	mkfs.btrfs "$device_disk"
}

# Create new partition
echo -e "\n====================\nCreate new partition\n====================\n"
while true; do
	read -r -n 1 -p $'\n'"Are you ready to create new partition? (y|n) " yn
	case $yn in
	[Yy]*)
		read -r -p $'\n'"Specify the size of the new disk in GiB? (y|n) " size_disk
		dev_disk=$(fdisk -l | grep "$size_disk GiB" | awk '{print $2}' | sed 's/.$//')
		read -r -p $'\n'"$dev_disk - Is the disk selected correctly? (y|n) " yn
		case $yn in
		[Yy]*)
			create_disk_partition "$dev_disk"
			echo -e "\nDONE\n"
			break
			;;
		[Nn]*)
			fdisk -l | grep	"$size_disk GiB"
			read -r -p $'\n'"Enter the name of the disk on which the partition will be created (format: /dev/vdb)" dev_disk
			create_disk_partition "$dev_disk"
			echo -e "\nDONE\n"
			break
			;;
		*) echo -e "\nPlease answer Y or N!\n" ;;
		esac
		;;
	[Nn]*)
		break
		;;
	*) echo -e "\nPlease answer Y or N!\n" ;;
    esac
done

# Mounting BTRFS in /backup
echo -e "\n====================\nMounting a BTRFS format partition \n====================\n"
while true; do
	set -x
	read -r -n 1 -p $'\n'"Are you ready to mounting new partition? (y|n) " yn
	case $yn in
	[Yy]*)
		# create backup dir
		if [ ! -d "$backup_dir" ]; then
			echo -e "\nCreate folder for backup: $backup_dir"
			mkdir "$backup_dir"
		else
			echo -e "\nFolder $backup_dir already exist"
		fi
		# add string in /etc/fstab
		UUID=$(blkid -s UUID -o value -t TYPE=btrfs)
		if ! grep -Fxq "UUID=$UUID /backup btrfs defaults 0 0" /etc/fstab &>/dev/null; then
          	echo "UUID=$UUID /backup btrfs defaults 0 0" >>/etc/fstab
          	echo -e "\nString 'UUID=$UUID $backup_dir btrfs defaults 0 0' added to /etc/fstab\n\n"
		fi
		# mount dev in dir
		mount -a
		df -h
		echo -e "\nDONE\n"
		break
		;;
	[Nn]*)
		break
		;;
	*) echo -e "\nPlease answer Y or N!\n" ;;
    esac
done

# Installing UrBackup
echo -e "\n====================\nInstalling UrBackup \n====================\n"
while true; do
    read -r -n 1 -p $'\n'"Are you ready to install UrBackup? (y|n) " yn
	case $yn in
	[Yy]*)
		# Add repository UrBackup server and update
		add-apt-repository ppa:uroni/urbackup <<EOF

EOF
		apt update -y

		# Check if the program is installed UrBackup
		if [ ! -d /etc/urbackup/ ]; then  # проверить правильность пути
			echo -e "\n====================\nUrBackup could not be found\nInstalling...\n====================\n"
			systemctl restart systemd-timesyncd.service
			apt install urbackup-server -y
			echo -e "\nDONE\n"
		else
			while true; do
				read -r -n 1 -p $'\n'"UrBackup already installing\nAre you ready to reinstall UrBackup? (y|n) " yn
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
		;;
	[Nn]*)
	break
	;;
	*) echo -e "\nPlease answer Y or N!\n" ;;
	esac
done

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