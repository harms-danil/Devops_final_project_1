#!/bin/bash

#completion="\n====================\n"

# Activate the option that interrupts script execution if any command terminates with a non-zero status
set -e

# Vars
dest_dir="/home/harms"
deb_name="openvpn-harms_2.5.5_amd64.deb"

# Check if the script is running from the root user
if [[ "${UID}" -ne 0 ]]; then
    echo "You need to run this script as root!"
    exit 1
fi

# Function that checks for the presence of a rule in iptables and, if missing, applies it
iptables_add() {
    if ! iptables -C "$@" &>/dev/null; then
        iptables -A "$@"
    fi
}

# Function that checks for the presence of a NAT-rule in iptables and, if missing, applies it
iptables_nat_add() {
    if ! iptables -t nat -C "$@" &>/dev/null; then
        iptables -t nat -A "$@"
    fi
}

# Function that checks the validity of a path on a linux system
path_request() {
    while true; do
        read -r -e -p $'\n\n'"Please input valid path to ${1}: " path
        if [ -f "$path" ]; then
            echo "$path"
            break
        fi
    done
}

# If need, uncomment
# Request the path of the future location of the easy-rsa working directory
#while true; do
#  read -r -e -p $'\n'"Path for easy-rsa location (format: /home/username): " dest_dir
#  if [[ "$dest_dir" == */ ]]; then
#    echo -e "\nWrong path format!\n"
#  else
#    if [ ! -d "$dest_dir" ]; then
#      echo -e "\nDirectory $dest_dir doesn't exist!\n"
#    else
#      break
#    fi
#  fi
#done

# Check if the program is installed OpenVPN
if [ ! -d /etc/openvpn/ ]; then
    echo -e "\n====================\nOpenVPN could not be found\nInstalling...\n====================\n"
    systemctl restart systemd-timesyncd.service
    wget -P $dest_dir/ https://github.com/harms-danil/Devops_final_project_1/raw/refs/heads/main/deb/"$deb_name"
    dpkg -i "$deb_name"
    echo -e "\nDONE\n"
else
    while true; do
    	echo -e "\n====================\nOpenVPN found!!!\nreInstalling...\n====================\n"
        read -r -n 1 -p $'\n'"Are you ready to reinstall easy-rsa? (y|n) " yn
        case $yn in
        [Yy]*)
            systemctl stop openvpn-server@server.service
            systemctl disable openvpn-server@server.service
            apt purge -y openvpn
            apt purge -y openvpn-harms
            rm -rf /etc/openvpn
            rm -rf /var/log/openvpn
            wget -P $dest_dir/ https://github.com/harms-danil/Devops_final_project_1/raw/refs/heads/main/deb/"$deb_name"
            dpkg -i "$deb_name"
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

# Config OpenVPN
echo -e "\n====================\nOpenVPN server config \n====================\n"

while true; do
    read -r -n 1 -p "Continue or Skip? (c|s) " cs
    case $cs in
    [Cc]*)
        # Check file /etc/sysctl.conf in system
        if [ ! -f /etc/sysctl.conf ]; then
            echo "File /etc/sysctl.conf not found!"
            exit 1
        fi

        # Request the path to the certificate file and transfer it to the working directory of the program
        server_crt=$(path_request certificate)
        cp "$server_crt" /etc/openvpn/server/
        server_crt_file=$(basename "$server_crt")

        # Request the path to the key file and transfer it to the working directory of the program
        server_key=$(path_request key)
        cp "$server_key" /etc/openvpn/server/
        server_key_file=$(basename "$server_key")

        # Request the path to the ca-certificate file and transfer it to the working directory of the program
        ca_crt=$(path_request "ca certificate")
        cp "$ca_crt" /etc/openvpn/server/
        cp "$ca_crt" /etc/openvpn/clients_conf/keys/
        ca_crt_file=$(basename "$ca_crt")

        cd /etc/openvpn/server/

        # Generate key for tls-crypt
        openvpn --genkey secret ta.key
        cp /etc/openvpn/server/ta.key /etc/openvpn/clients_conf/keys/
        echo -e "\n====================\nTls-crypt-key generated /etc/openvpn/server/ta.key \n====================\n"

        # Make changes to the configuration file open-vpn
        sed -r -i 's/(^ca\s).*$/\1'"$ca_crt_file"'/' /etc/openvpn/server/server.conf
        sed -r -i 's/(^cert\s).*$/\1'"$server_crt_file"'/' /etc/openvpn/server/server.conf
        sed -r -i 's/(^key\s).*$/\1'"$server_key_file"'/' /etc/openvpn/server/server.conf

        # Activate ip forward
        echo -e "\n====================\nIp forward configure \n====================\n"
        sed -i 's/#\?\(net.ipv4.ip_forward=1\s*\).*$/\1/' /etc/sysctl.conf
        sysctl -p
        echo -e "\nDONE\n"

        # Config openvpn
        echo -e "\n====================\nOpenVPN configuration \n====================\n"

        # Request to enter the port through which openvpn will work
        while true; do
            read -r -p $'\n\n'"OpenVPN port number (default 1194): " port
            re='^[0-9]+$'
            if ! [[ $port =~ $re ]]; then
                echo "error: Not a number" >&2
                #exit 1
            else
                if [ "$port" == 1194 ]; then
                    break
                else
                    # if the port differs from 1194, we will make changes to the configuration file
                    sed -r -i 's/(^port\s).*$/\1'"$port"'/' /etc/openvpn/server/server.conf
                    sed -r -i 's/(^port\s).*$/\1'"$port"'/' /etc/openvpn/clients_conf/files/base.conf
                    break
                fi
            fi
        done

        echo -e "\n"
        ip a
        echo -e "\n"

        # Request hostname or ip openvpn server and put it in the configuration file
        read -r -p $'\n'"The hostname or IP of the server: " host
        sed -r -i 's/(^remote\s).*$/\1'"$host"' '"$port"'/' /etc/openvpn/clients_conf/files/base.conf

        echo -e "\n====================\nIptables configuration\n====================\n"

        # Request the name of the vpn interface to configure iptables
        while true; do
            read -r -p $'\n'"VPN interface name: " eth
            if ! ip a | grep -q "$eth"; then
                echo -e "\nWrong interface name!\n"
            else
                break
            fi
        done

        # Config iptables
        # OpenVPN
        iptables_add INPUT -i "$eth" -m conntrack --ctstate NEW -p udp --dport "$port" -j ACCEPT -m comment --comment openvpn
        # Allow TUN interfaces connections to OpenVPN server
        iptables_add INPUT -i tun+ -j ACCEPT -m comment --comment openvpn
        # Allow TUN interfaces connections to be forwarded through interfaces
        iptables_add FORWARD -i tun+ -j ACCEPT -m comment --comment openvpn
        iptables_add FORWARD -i tun+ -o "$eth" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT -m comment --comment openvpn
        iptables_add FORWARD -i "$eth" -o tun+ -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT -m comment --comment openvpn
        # NAT the VPN client traffic to the interface
        iptables_nat_add POSTROUTING -s 10.8.0.0/24 -o "$eth" -j MASQUERADE -m comment --comment openvpn
        echo -e "\n====================\nSaving iptables config\n====================\n"
        service netfilter-persistent save
        echo -e "\nDONE\n"

        # Restart service openvpn
        echo -e "\n====================\nRestarting Open-VPN service...\n====================\n"
        systemctl restart openvpn-server@server.service
        systemctl enable openvpn-server@server.service

        echo -e "\n====================\nEnter password fo ca server certificate \n====================\n"
        systemd-tty-ask-password-agent

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

# Configure the client configuration file
echo -e "\n====================\nCreate OpenVPN client config-file\n===================="

while true; do
    read -r -n 1 -p "Continue or Skip? (c|s) " cs
    case $cs in
    [Cc]*)
        read -r -p $'\n'"Client name: " client_name
        # Request a client certificate and transfer it to the working directory of the program
        client_crt=$(path_request "client certificate")
        cp "$client_crt" /etc/openvpn/clients_conf/keys/

        # Request a client key and transfer it to the working directory of the program
        client_key=$(path_request "client key")
        cp "$client_key" /etc/openvpn/clients_conf/keys/

        # Run the script to generate the client configuration file
        if /etc/openvpn/clients_conf/make-config.sh "$client_name"; then
            echo -e "\nDONE!\n\nCheck file /etc/openvpn/clients_conf/files/${client_name}.ovpn"
        fi
        break
        ;;
  [Ss]*)
    echo -e "\n"
    break
    ;;
  *) echo -e "\nPlease answer C or S!\n" ;;
  esac
done

# Request copy client config file
echo -e "\n====================\nCopy client config file to directory /home/$SUDO_USER/client_config\n===================="

while true; do
    read -r -n 1 -p "Copy or No? (c|n) " cn
    case $cn in
    [Cc]*)
        if [ ! -d /home/$SUDO_USER/client_config ]; then
            echo -e "\nDirectory /home/$SUDO_USER/client_config not found!\nCreate\n"
            cd /home/$SUDO_USER
            mkdir client_config
            echo -e "\nDone\n"
        fi
        echo -e "Copy client config file to directory /home/$SUDO_USER/client_config"
        cp /etc/openvpn/clients_conf/files/${client_name}.ovpn /home/$SUDO_USER/client_config/
        echo -e "\nDONE!\n\nCheck file /home/$SUDO_USER/client_config/${client_name}.ovpn"
        break
        ;;
    [Nn]*)
        echo -e "\n"
        break
        ;;
    *) echo -e "\nPlease answer C or S!\n" ;;
    esac
done

# Delete deb-package
rm "$dest_dir"/"$deb_name"
echo -e "\nDeb-package remove\n"

echo -e "\nOK, OpenVPN server installed and configured\n"
exit 0