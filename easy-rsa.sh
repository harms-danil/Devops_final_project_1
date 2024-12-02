#!/bin/bash

set -e

# Vars
deb_name="easy-rsa-harms_0.2_all.deb"

# Check if the script is running from the root user
if [[ "${UID}" -ne 0 ]]; then
  echo "You need to run this script as root!"
  exit 1
fi

# Request the path of the future location of the easy-rsa working directory
while true; do
  read -r -e -p $'\n'"Path for easy-rsa location (format: /home/username): " dest_dir
  if [[ "$dest_dir" == */ ]]; then
    echo -e "\nWrong path format!\n"
  else
    if [ ! -d "$dest_dir" ]; then
      echo -e "\nDirectory $dest_dir doesn't exist!\n"
    else
      break
    fi
  fi
done

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
      apt purge -y easy-rsa-harms
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
  [Nn]*) exit ;;
  *) echo -e "\nPlease answer Y or N!\n" ;;
  esac
done

# Delete deb-package
rm "$dest_dir"/easy-rsa-harms*
echo -e "\nDeb-package remove\n"

echo -e "\nOK, CA installed\n"
exit 0