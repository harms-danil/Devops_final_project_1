#!/bin/bash

# Activate the option that interrupts script execution if any command terminates with a non-zero status
set -e

# Vars
dest_dir="/home/harms"
deb_name="easy-rsa-harms_0.2_all.deb"

# Check if the script is running from the root user
if [[ "${UID}" -ne 0 ]]; then
    echo "You need to run this script as root!"
    exit 1
fi

# Check if the program is installed Easy-RSA
if [ ! -d /usr/share/easy-rsa/ ]; then
    echo -e "\n====================\nEasy-rsa could not be found\nInstalling...\n====================\n"
    systemctl restart systemd-timesyncd.service
    wget -P $dest_dir/ https://github.com/harms-danil/Devops_final_project_1/raw/refs/heads/main/deb/"$deb_name"
    dpkg -i "$deb_name"
    echo -e "\nDONE\n"
else
    while true; do
        read -r -n 1 -p $'\n'"Are you ready to reinstall easy-rsa? (y|n) " yn
        case $yn in
        [Yy]*)
            apt purge -y easy-rsa || apt purge -y easy-rsa-harms
            wget -P $dest_dir/ https://github.com/harms-danil/Devops_final_project_1/raw/refs/heads/main/deb/"$deb_name"
            dpkg -i "$deb_name"
            echo -e "\nDONE\n"
            break
            ;;
        [Nn]*) exit ;;
        *) echo -e "\nPlease answer Y or N!\n" ;;
        esac
    done
fi

# Request username from the Easy-RSA administrator and create a symbolic link to the Easy-RSA work directory in the
# work directory of the entered user
while true; do
    read -r -p $'\n'"Easy-rsa owner username: " username
    if id "$username" >/dev/null 2>&1; then
        if [ ! -d "$dest_dir"/easy-rsa/ ]; then
            mkdir "$dest_dir"/easy-rsa
        else
            break
        fi
        ln -s /usr/share/easy-rsa/* "$dest_dir"/easy-rsa/
        chmod -R 700 /usr/share/easy-rsa/
        chown -R "$username":"$username" /usr/share/easy-rsa/
        break
    else
        echo -e "\nUser $username doesn't exists!\n"
    fi
done

# Create a pair of CA keys
while true; do
    read -r -n 1 -p $'\n'"Are you ready to create pair of CA keys? (y|n) " yn
    case $yn in
    [Yy]*)
        cd "$dest_dir"/easy-rsa
        sudo -u "$username" ./easyrsa build-ca
        echo -e "\nDONE\n"
        break
        ;;
    [Nn]*)
        exit
        ;;
    *) echo -e "\nPlease answer Y or N!\n" ;;
    esac
done

#Помещаем корневой сертификат в каталог /usr/local/share/ca-certificates/ и выполняем команду:
#cp $dest_dir"/easy-rsa/pki/ca.crt /usr/local/share/ca-certificates/
#update-ca-certificates

# Delete deb-package
rm "$dest_dir"/"$deb_name"
echo -e "\nDeb-package remove\n"

echo -e "\nOK, CA installed\n"
exit 0