#!/bin/bash

# Activate the option that interrupts script execution if any command terminates with a non-zero status
set -e

# Vars
dest_dir="/home/harms"
deb_name_node="node-exporter-harms_1.8.2-1_all.deb"
deb_name_openvpn="openvpn-exporter-harms_0.3.0_all.deb"


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

# Function that checks whether the IP address is entered correctly
ip_request() {
    while true; do
        read -r -p $'\n'"Enter monitor vm ip (format 10.130.0.4): " ip
        if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "$ip"
            break
        fi
    done
}

# Function that checks the validity of a path on a linux system
path_request() {
    while true; do
        read -r -e -p $'\n'"Please input valid path to ${1}: " path
        if [ -f "$path" ]; then
            echo "$path"
            break
        fi
  done
}

# Menu with a suggestion to select an exporter for installation
while true; do
    echo -e "\n--------------------------\n"
    echo -e "[1] node exporter\n"
    echo -e "[2] openvpn exporter\n"
    echo -e "[3] exit\n"
    echo -e "--------------------------\n"
    read -r -n 1 -p "Select exporter for install: " exporter

    case $exporter in
    # Install node-exporter
    1)
        echo -e "\n====================\nNode Exporter Installing...\n====================\n"
        # Check if the program is installed Node Exporter
        if [ ! -f /usr/bin/node_exporter ]; then
            echo -e "\n====================\nNode Exporter could not be found\nInstalling...\n====================\n"
            systemctl restart systemd-timesyncd.service
            wget -P $dest_dir/ https://github.com/harms-danil/Devops_final_project_1/raw/refs/heads/main/deb/"$deb_name_node"
            dpkg -i "$deb_name_node"
#            if [ ! -d opt/node_exporter/ ]; then
#                mkdir /opt/node_exporter/
#            fi
            rm "$deb_name_node"
            echo -e "\nDONE\n"
        else
            while true; do
                read -r -n 1 -p $'\n'"Are you ready to reinstall Node Exporter (y|n) " yn
                case $yn in
                [Yy]*)
                    systemctl stop node_exporter.service
                    systemctl disable node_exporter.service
                    apt purge -y node-exporter-harms || rm -rf /opt/node_exporter/
                    wget -P $dest_dir/ https://github.com/harms-danil/Devops_final_project_1/raw/refs/heads/main/deb/"$deb_name_node"
                    dpkg -i "$deb_name_node"
#                    if [ ! -d /opt/node_exporter/ ]; then
#                        mkdir /opt/node_exporter/
#                    fi
                    rm "$deb_name_node"
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
        # request the paths to the certificate and key files for this vm
        cert_path=$(path_request certificate)
        cert_file=$(basename "$cert_path")

        key_path=$(path_request key)
        key_file=$(basename "$key_path")

        # Copy the key and certificate files to the working directory of the program and change ownership rights
        cp "$cert_path" /opt/node_exporter/
        cp "$key_path" /opt/node_exporter/
        chmod 640 /opt/node_exporter/"$cert_file"
        chmod 640 /opt/node_exporter/"$key_file"
        chown node_exporter:node_exporter /opt/node_exporter/"$cert_file"
        chown node_exporter:node_exporter /opt/node_exporter/"$key_file"

        # Request the authorization data and write it to the configuration file
        read -r -p $'\n'"Node Exporter username: " username
        read -r -p $'\n'"Node Exporter password: " -s password
        echo -e "tls_server_config:\n  cert_file: $cert_file\n  key_file: $key_file\n\nbasic_auth_users:\n  $username: '$(htpasswd -nbB -C 10 admin "$password" | grep -o "\$.*")'" >/opt/node_exporter/web.yml

        # Setting up iptables
        echo -e "\n====================\nIptables configuration\n====================\n"
        monitor_vm_ip=$(ip_request)
        iptables_add INPUT -p tcp -s "$monitor_vm_ip" --dport 9100 -j ACCEPT -m comment --comment prometheus_node_exporter
        echo -e "\n====================\nSaving iptables config\n====================\n"
        service netfilter-persistent save
        echo -e "\nDONE\n"

        # Restart node_exporter.service
        systemctl daemon-reload
        systemctl restart node_exporter.service
        systemctl enable node_exporter.service

        echo -e "\n====================\nNode Exporter listening on port 9100\n====================\n"
        echo -e "\nOK\n"
        ;;

    2)
        echo -e "\n====================\nOpenvpn Exporter Installing...\n====================\n"
        # Check if the program is installed OpenVPN Exporter
        if [ ! -f /usr/bin/openvpn_exporter ]; then
            echo -e "\n====================\nNode Exporter could not be found\nInstalling...\n====================\n"
            systemctl restart systemd-timesyncd.service
            wget -P $dest_dir/ https://github.com/harms-danil/Devops_final_project_1/raw/refs/heads/main/deb/"$deb_name_openvpn"
            dpkg -i "$deb_name_openvpn"
            rm "$deb_name_openvpn"
            echo -e "\nDONE\n"
        else
            while true; do
                read -r -n 1 -p $'\n'"Are you ready to reinstall OpenVPN Exporter (y|n) "$'\n' yn
                case $yn in
                [Yy]*)
                    systemctl stop openvpn_exporter.service
                    systemctl disable openvpn_exporter.service
                    apt purge -y openvpn-exporter-harms
                    wget -P $dest_dir/ https://github.com/harms-danil/Devops_final_project_1/raw/refs/heads/main/deb/"$deb_name_openvpn"
                    dpkg -i "$deb_name_openvpn"
                    rm "$deb_name_openvpn"
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

      # Setting up iptables
      echo -e "\n====================\nIptables configuration\n====================\n"
      monitor_vm_ip=$(ip_request)
      iptables_add INPUT -p tcp -s "$monitor_vm_ip" --dport 9176 -j ACCEPT -m comment --comment prometheus_openvpn_exporter
      echo -e "\n====================\nSaving iptables config\n====================\n"
      service netfilter-persistent save
      echo -e "\nDONE\n"

      # Restart openvpn_exporter.service
      systemctl daemon-reload
      systemctl restart openvpn_exporter.service
      systemctl enable openvpn_exporter.service

      echo -e "\n====================\nOpenvpn Exporter listening on port 9176\n====================\n"
      echo -e "\nOK\n"
      ;;

    3)
      echo -e "\n\nOK\n"
      exit 0
      ;;

    *)
      echo -e "\n\nUnknown\n"
      ;;
    esac
done