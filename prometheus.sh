#!/bin/bash

# Activate the option that interrupts script execution if any command terminates with a non-zero status
set -e

# Vars
dest_dir="/home/harms"
deb_name_prometheus="prometheus-harms_2.55.1.linux-amd64_all.deb"
deb_name_alertmanager="alertmanager-harms_0.27.0.linux-amd64_all.deb"

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

# Menu with a suggestion to select a service for installation
while true; do
    echo -e "\n--------------------------\n"
    echo -e "[1] Prometheus\n"
    echo -e "[2] Alertmanager\n"
#    echo -e "[3] Grafana\n"
    echo -e "[3] exit\n"
    echo -e "--------------------------\n"
    read -r -n 1 -p "Select service for install: " service

    case $service in
    # Install Prometheus
    1)
        # Check if the program is installed Prometheus
        if [ ! -d /etc/prometheus/ ]; then
            echo -e "\n====================\nPrometheus could not be found\nInstalling...\n====================\n"
            systemctl restart systemd-timesyncd.service
            wget -P $dest_dir/ https://github.com/harms-danil/Devops_final_project_1/raw/refs/heads/main/deb/"$deb_name_prometheus"
            dpkg -i "$deb_name_prometheus"
            rm -f "$deb_name_prometheus"
            echo -e "\nDONE\n"
        else
            while true; do
                read -r -n 1 -p $'\n'"Are you ready to reinstall Prometheus (y|n) "$'\n' yn
                case $yn in
                [Yy]*)
                    systemctl stop prometheus.service
                    systemctl disable prometheus.service
                    apt purge -y prometheus || apt purge -y prometheus-harms
                    wget -P $dest_dir/ https://github.com/harms-danil/Devops_final_project_1/raw/refs/heads/main/deb/"$deb_name_prometheus"
                    dpkg -i "$deb_name_prometheus"
                    rm -f "$deb_name_prometheus"
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
    2)
        # Check if the program is installed Alertmanager
        if [ ! -d /etc/prometheus/alertmanager ]; then
            echo -e "\n====================\nAlertmanager could not be found\nInstalling...\n====================\n"
            systemctl restart systemd-timesyncd.service
            wget -P $dest_dir/ https://github.com/harms-danil/Devops_final_project_1/raw/refs/heads/main/deb/"$deb_name_alertmanager"
            dpkg -i "$deb_name_alertmanager"
            rm -f "$deb_name_alertmanager"
            echo -e "\nDONE\n"
        else
            while true; do
                read -r -n 1 -p $'\n'"Are you ready to reinstall Alertmanager (y|n) "$'\n' yn
                case $yn in
                [Yy]*)
                    systemctl stop prometheus-alertmanager.service
                    systemctl disable prometheus-alertmanager.service
                    apt purge -y alertmanager || apt purge -y alertmanager-harms
                    wget -P $dest_dir/ https://github.com/harms-danil/Devops_final_project_1/raw/refs/heads/main/deb/"$deb_name_alertmanager"
                    dpkg -i "$deb_name_alertmanager"
                    rm -f "$deb_name_alertmanager"
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
    3)
        echo -e "\n\nOK\n"
        break
        ;;
    *)
        echo -e "\n\nUnknown\n"
        ;;
    esac
done

# Request the address of the private network and check it for correctness
while true; do
  read -r -p $'\n'"Private network (format 10.130.0.0/24): " private_net
  if [[ ! $private_net =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,2}$ ]]; then
    echo -e "\nPrefix not valid!\n"
  else
    break
  fi
done

# Set up iptables
echo -e "\n====================\nIptables configuration \n====================\n"
iptables_add INPUT -p tcp --dport 9090 -j ACCEPT -m comment --comment prometheus
iptables_add INPUT -p tcp --dport 9093 -j ACCEPT -m comment --comment prometheus_alertmanager
iptables_add OUTPUT -p tcp --dport 587 -j ACCEPT -m comment --comment smtp
iptables_add OUTPUT -p tcp -d "$private_net" --dport 9100 -j ACCEPT -m comment --comment prometheus_node_exporter
iptables_add OUTPUT -p tcp -d "$private_net" --dport 9176 -j ACCEPT -m comment --comment prometheus_openvpn_exporter
echo -e "\n====================\nSaving iptables config \n====================\n"
service netfilter-persistent save
echo -e "\nDONE\n"

# Set up HTTPS
echo -e "\n====================\nHTTPS configuration \n====================\n"

# Request the path to the certificate file and transfer it to the working directory of the program
echo -e "\nPath for certificate server"
cert_path=$(path_request certificate)
cp "$cert_path" /etc/prometheus/
cert_file=$(basename "$cert_path")
chmod 640 /etc/prometheus/"$cert_file"
chown prometheus:prometheus /etc/prometheus/"$cert_file"

# Request the path to the key file and transfer it to the working directory of the program
echo -e "\nPath for key server"
key_path=$(path_request key)
cp "$key_path" /etc/prometheus/
key_file=$(basename "$key_path")
chmod 640 /etc/prometheus/"$key_file"
chown prometheus:prometheus /etc/prometheus/"$key_file"

# transfer the certificates of exporters to the prometheus directory
while true; do
  read -r -n 1 -p $'\n\n'"Add exporter's certificate to prometheus directory? (y|n) " yn
  case $yn in
  [Yy]*)
    exp_cert_path=$(path_request certificate)
    cp "$exp_cert_path" /etc/prometheus/
    exp_cert_file=$(basename "$exp_cert_path")
    chmod 640 /etc/prometheus/"$exp_cert_file"
    chown prometheus:prometheus /etc/prometheus/"$exp_cert_file"
    ;;
  [Nn]*)
    echo -e "\n"
    break
    ;;
  *) echo -e "\nPlease answer Y or N!\n" ;;
  esac
done

# request a username and password to log in to the program
read -r -p $'\n'"Prometheus username: " username
read -r -p $'\n'"Prometheus password: " -s password

# request a domain name to connect prometheus to alertmanager
read -r -p $'\n\n'"Prometheus domain name (format monitor.harms-devops.ru): " domain_name

# write the settings to the configuration file /etc/prometheus/web.yml
echo -e "tls_server_config:\n  cert_file: $cert_file\n  key_file: $key_file\n\nbasic_auth_users:\n  $username: '$(htpasswd -nbB -C 10 admin "$password" | grep -o "\$.*")'" >/etc/prometheus/web.yml

# внесем изменения в конфигурационный файл /etc/prometheus/prometheus.yml в блок alerting
sed -r -i '/(^.*\susername:\s).*$/s//\1'"$username"'/' /etc/prometheus/prometheus.yml       # убрал 0,
sed -r -i '/(^.*\spassword:\s).*$/s//\1'"$password"'/' /etc/prometheus/prometheus.yml
sed -r -i '0,/(^.*\sca_file:\s).*$/s//\1'"$cert_file"'/' /etc/prometheus/prometheus.yml
sed -r -i "0,/(^.*\stargets:\s).*/s//\1['$domain_name:9093']/" /etc/prometheus/prometheus.yml

# выполним настройку DNS
echo -e "\n\n====================\nDNS configuration\n====================\n"

# Change the /etc/cloud/cloud.sap.d/95-cloud file.sap the value of the manager_etc_hosts parameter
# from true to false to save /etc/hosts after reboot
sed -r -i '0,/(^.*\smanage_etc_hosts:\s).*$/s//\1'false'/' /etc/cloud/cloud.cfg.d/95-cloud.cfg

# закрепим доменное имя prometheus за адресом localhost
if ! grep -Fxq "127.0.0.1 $domain_name" /etc/hosts &>/dev/null; then
  echo "127.0.0.1 $domain_name" >>/etc/hosts
  echo -e "\nString '127.0.0.1 $domain_name' added to /etc/hosts\n\n"
fi

echo -e "/etc/hosts file content:\n\n"
cat /etc/hosts

# запросим у пользователя строки для добавления в /etc/hosts
while true; do
    read -r -n 1 -p $'\n\n'"Add new string to /etc/hosts? (y|n) " yn
    case $yn in
    [Yy]*)
        while true; do
            read -r -p $'\n\n'"Enter string in format '<ip> <domain>': " domain_str
            if [[ $domain_str =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}[[:blank:]][a-z\.-]{2,3}+$ ]]; then
                if ! grep -Fxq "$domain_str" /etc/hosts &>/dev/null; then
                    echo -e "\nString $domain_str added to /etc/hosts\n\n"
                    echo "$domain_str" >>/etc/hosts
                    echo -e "\n\n/etc/hosts file content:\n\n"
                    cat /etc/hosts
                else
                    echo -e "\nString $domain_str already exist"
                fi
                break
            else
                echo -e "\nWrong string format!\n"
            fi
        done
        ;;
    [Nn]*)
        echo -e "\n"
        break
        ;;
    *) echo -e "\nPlease answer Y or N!\n" ;;
    esac
done

# Restart service prometheus и alertmanager
echo -e "\nDONE\n"
systemctl daemon-reload
systemctl restart prometheus.service
systemctl enable prometheus.service
systemctl restart prometheus-alertmanager.service
systemctl enable prometheus-alertmanager.service

echo -e "\n====================\nPrometheus listening on port 9090\nAlertmanager listening on port 9093\n===================="
echo -e "\nOK\n"
exit 0
