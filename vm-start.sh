#!/bin/bash

set -e

# Vars
file_ssh_keys="/root/.ssh/authorized_keys"
file_ssh="/etc/ssh/sshd_config"
file_grub="/etc/default/grub"
port="1985"
#completion="\n====================\n"
export DEBEMAIL="harmsss@yandex.ru"
export DEBFULLNAME="Harms"
source ~/.bashrc

# Check if the script is running from the root user
if [[ "${UID}" -ne 0 ]]; then
    echo -e "You need to run script as root!\nPlease apply 'sudo' and add your host-key to $file_ssh_keys before run this script!"
    exit 1
fi

# Check if the public ssh keys are downloaded from the root user
if [[ ! -f $file_ssh_keys ]]; then
    echo -e "\n---------- File $file_ssh_keys not found! ----------\n"
    exit 1
fi
if [[ ! -s $file_ssh_keys ]]; then
    echo -e "\n---------- File $file_ssh_keys is empty! ----------\n"
    exit 1
fi

# Function that checks for the presence of a package in the system and, if it is missing, performs the installation
command_check() {
    if ! command -v "$1" &>/dev/null; then
        echo -e "\n====================\n $2 could not be found! Installing... \n====================\n"
        apt install -y "$3"
        echo -e "\nInstall ok!\n"
    fi
}

# Function that requests the name of a new user and checks for its presence in the system
user_check() {
    while true; do
        read -r -p $'\n'"New username: " username
        if id "$username" >/dev/null 2>&1; then
            echo -e "\nUser $username exist!\n"
        else
            break
        fi
    done
}

# Function that checks for the presence of a rule in iptables and, if missing, applies it
iptables_add() {
  if ! iptables -C "$@" &>/dev/null; then
    iptables -A "$@"
  fi
}

# Setting time-zone
echo -e "\n====================\nSetting timezone \n====================\n"
timedatectl set-timezone Europe/Moscow
systemctl restart systemd-timesyncd.service
timedatectl
echo -e "\nDONE\n"

# Install all the necessary packagesapt-get update
apt update && apt upgrade -y
command_check wget "Wget" wget
command_check iptables "Iptables" iptables
command_check netfilter-persistent "Netfilter-persistent" iptables-persistent
command_check openssl "OpenSSL" openssl
command_check update-ca-certificates "Ca-certificates" ca-certificates
command_check basename "Basename" coreutils
command_check htpasswd "Htpasswd" apache2-utils

# Check file ssh
if [ ! -f "$file_ssh" ]; then
    echo -e "\n====================\nFile $file_ssh not found! \n====================\n"
    exit 1
fi

# Check file grub
if [ ! -f "$file_grub"  ]; then
    echo -e "\n====================\nFile $file_grub not found! \n====================\n"
    exit 1
fi

# Create or change password
echo -e "\n====================\nCreate or change password \n====================\n"
while true; do
    read -r -p "Continue or Skip (c|s) " cs
    case $cs in
        [Cc]*)
            echo -e "\nChange password for $SUDO_USER\n"
            # Request user password
            read -r -p "New password: " -s password_new

            # Change password and add to group sudo and add bash
            usermod -p "$(openssl passwd -1 "$password_new")" "$SUDO_USER"
            usermod -s /bin/bash -aG sudo $SUDO_USER
            echo -e "\nDONE\n"
            break
            ;;
        [Ss]*)
            echo -e "\n"
            break
            ;;
        *) echo -e "\nPlease answer C or S!\n" ;;
    esac
done

# Create new user
echo -e "\n====================\nNew user config \n====================\n"
while true; do
    read -r -p "Continue or Skip? (c|s) " cs
    case $cs in
        [Cc]*)
            # Request user name use function user_check()
            user_check

            # Request password for new user
            read -r -p "New password: " -s password

            # Create new user and copy ssh-keys, if user not exist
            echo -e "\nCreate new user $username \n"
            useradd -p "$(openssl passwd -1 "$password")" "$username" -s /bin/bash -m -G sudo
            cp -r /root/.ssh/ /home/"$username"/ && chown -R "$username":"$username" /home/"$username"/.ssh/
            echo -e "\nDONE\n"
            break
            ;;
        [Ss]*)
            echo -e "\n"
            break
            ;;
        *) echo -e "\nPlease answer C or S!\n" ;;
    esac
done

# Setting sshd_config
echo -e "\n====================\nEdit sshd_config file \n====================\n"

while true; do
    read -r -p "Continue or Skip? (c|s) " cs
    case $cs in
        [Cc]*)
            sed -i "s/#\?\(Port\s*\).*$/\1 ${port}/" $file_ssh
            sed -i 's/#\?\(PermitRootLogin\s*\).*$/\1 no/' $file_ssh
            sed -i 's/#\?\(PubkeyAuthentication\s*\).*$/\1 yes/' $file_ssh
            sed -i 's/#\?\(PermitEmptyPasswords\s*\).*$/\1 no/' $file_ssh
            sed -i 's/#\?\(PasswordAuthentication\s*\).*$/\1 no/' $file_ssh
            # Increasing ssh timeout time
            sed -i 's/#\?\(ClientAliveInterval\s*\).*$/\1 3000/' $file_ssh
            sed -i 's/#\?\(ClientAliveCountMax\s*\).*$/\1 3/' $file_ssh
            echo -e "\n\n"
            /etc/init.d/ssh restart
            echo -e "\nDONE\n"
            break
            ;;
        [Ss]*)
            echo -e "\n"
            break
            ;;
        *) echo -e "\nPlease answer C or S!\n" ;;
    esac
done

# Disable ipv6
echo -e "\n====================\nDisabling ipv6 \n====================\n"

while true; do
    read -r -p "Continue or Skip? (c|s) " cs
    case $cs in
        [Cc]*)
            echo -e "\n\n"
            sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/&ipv6.disable=1 /' $file_grub 
            sed -i 's/^GRUB_CMDLINE_LINUX="/&ipv6.disable=1 /' $file_grub
            update-grub
            echo -e "\nDONE\n"
            break
            ;;
        [Ss]*)
            echo -e "\n"
            break
            ;;
        *) echo -e "\nPlease answer C or S!\n" ;;
    esac
done

# Setting iptables
echo -e "\n====================\nIptables config \n====================\n"
while true; do
    read -r -p "Current ssh session may drop! To continue you have to relogin to this host via $port ssh-port and run this script again. Are you ready? (y|n) " yn
    case $yn in
        [Yy]*) 
            # DNS
            iptables_add OUTPUT -p tcp --dport 53 -j ACCEPT -m comment --comment dns
            iptables_add OUTPUT -p udp --dport 53 -j ACCEPT -m comment --comment dns
            # NTP
            iptables_add OUTPUT -p udp --dport 123 -j ACCEPT -m comment --comment ntp
            # ICMP
            iptables_add OUTPUT -p icmp -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
            iptables_add INPUT -p icmp -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
            # Loopback
            iptables_add OUTPUT -o lo -j ACCEPT
            iptables_add INPUT -i lo -j ACCEPT
            # INPUT and OUTPUT SSH
            iptables_add INPUT -p tcp --dport $port -j ACCEPT -m comment --comment ssh_input
            iptables_add OUTPUT -p tcp --dport $port -j ACCEPT -m comment --comment ssh_output
            # OUTPUT HTTP 
            iptables_add OUTPUT -p tcp -m multiport --dports 443,80 -j ACCEPT
            # ESTABLISHED
            iptables_add INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
            iptables_add OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
            # INVALID
            iptables_add OUTPUT -m conntrack --ctstate INVALID -j DROP
            iptables_add INPUT -m conntrack --ctstate INVALID -j DROP
            # Defaul DROP
            iptables -P OUTPUT DROP
            iptables -P INPUT DROP
            iptables -P FORWARD DROP

            # save iptables config
            echo -e "\n====================\nSaving iptables config \n====================\n"
            service netfilter-persistent save
            echo -e "DONE\n"
            break
            ;;
        [Nn]*)
            echo -e "\n"
            break
            ;;
        *) echo -e "\nPlease answer Y or N!\n" ;;
    esac
done

# Create keys directory
if [ ! -d /home/$SUDO_USER/keys ]; then
    echo -e "\n====================\nDirectory /home/$SUDO_USER/keys not found!\nCreate... \n====================\n"
    mkdir keys
    chmod 700 /home/$SUDO_USER/keys
    chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/keys
    echo -e "\nDONE\n"
    exit 0
else
    echo -e "\n====================\nDirectory /home/$SUDO_USER/keys found! \n====================\n"
    exit 1
fi

echo -e "\nSetting for VM is OK!!!\n"
exit 0


