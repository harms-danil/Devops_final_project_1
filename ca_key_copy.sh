#!/bin/bash

set -e

# Vars
port=1985

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

# Request the server part where to copy the keys and certificate
read -r -e -p "Enter the server path (format: username@hostname(ip-address)): " server_path

# Copy ca.srt
echo -e "\n====================\nCopy ca.crt\n====================\n"
while true; do
    read -r -n 1 -p "Continue or Skip (c|s) " cs
    case $cs in
        [Cc]*)
            scp -P $port "$dest_dir"/easy-rsa/pki/ca.crt  "$server_path":~/keys
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

# Copy server certificate and key
echo -e "\n====================\nCopy server certificate and key\n====================\n"
while true; do
    read -r -n 1 -p "Continue or Skip (c|s) " cs
    case $cs in
        [Cc]*)
            read -r -e -p "\nEnter the name of the server for which the certificate was issued: " server_name
            echo -e "\n====================\nCopy '$server_name'.crt\n====================\n"
            scp -P $port "$dest_dir"/easy-rsa/pki/issued/"$server_name".crt "$server_path":~/keys
            echo -e "\n====================\nCopy '$server_name'.key\n====================\n"
            scp -P $port "$dest_dir"/easy-rsa/pki/private/"$server_name".key "$server_path":~/keys
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

# Copy client certificate and key
echo -e "\n====================\nCopy client certificate and key\n====================\n"
while true; do
    read -r -n 1 -p "Continue or Skip (c|s) " cs
    case $cs in
        [Cc]*)
            read -r -e -p "\nEnter the name of the server for which the certificate was issued: " client_name
            echo -e "\n====================\nCopy $client_name.crt\n====================\n"
            scp -P $port "$dest_dir"/easy-rsa/pki/issued/"$client_name".crt "$server_path":~/keys
            echo -e "\n====================\nCopy $client_name.key\n====================\n"
            scp -P $port "$dest_dir"/easy-rsa/pki/private/"$client_name".key "$server_path":~/keys
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
