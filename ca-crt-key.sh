#!/bin/bash

# Activate the option that interrupts script execution if any command terminates with a non-zero status
set -e

# Vars
port=1985
host="harms-devops.ru"
dest_dir="/home/harms"
username="harms"

# Request the path of the future location of the easy-rsa working directory
#while true; do
#    read -r -e -p $'\n'"Path for easy-rsa location (format: /home/username): " dest_dir
#    if [[ "$dest_dir" == */ ]]; then
#       echo -e "\nWrong path format!\n"
#    else
#        if [ ! -d "$dest_dir" ]; then
#            echo -e "\nDirectory $dest_dir doesn't exist!\n"
#        else
#            break
#        fi
#    fi
#done

# Request the server part where to copy the keys and certificate
read -r -e -p "Enter the SUB_name server path (format: username@SUB.hostname): " sub_name
server_path_ssh="$username@$sub_name.$host"
server_name="$sub_name.$host"
echo -e "\n$server_name \n"
echo -e "\n$server_path \n"

# Create pair crt and key
echo -e "\n====================\nCreate crt and key \n====================\n"
while true; do
    read -r -n 1 -p $'\n'"Continue or Skip (c|s) " cs
    case $cs in
        [Cc]*)
            if [ ! -f "$dest_dir"/easy-rsa/pki/private/"$server_name".key ]; then
                cd $dest_dir/easy-rsa
                ./easyrsa gen-req "$server_name" nopass
                if [ ! -f $dest_dir/easy-rsa/pki/issued/"$server_name".crt ]; then
                    ./easyrsa sign-req server "$server_name"
                else
                    echo -e "\nFile $dest_dir/easy-rsa/pki/issued/$server_name found!\nNeed remove him...\n"
                    exit 1
                fi
            else
                echo -e "\nFile $dest_dir/easy-rsa/pki/private/$server_name found!\nNeed remove him...\n"
                exit 1
            fi
            # remove req
            rm $dest_dir/easy-rsa/pki/reqs/"$server_name
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

# Copy ca.srt
echo -e "\n====================\nCopy ca.crt\n====================\n"
while true; do
    read -r -n 1 -p $'\n'"Continue or Skip (c|s) " cs
    case $cs in
        [Cc]*)
            scp -P $port "$dest_dir"/easy-rsa/pki/ca.crt  "$server_path_ssh":~/keys
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
    read -r -n 1 -p $'\n'"Continue or Skip (c|s) " cs
    case $cs in
        [Cc]*)
            echo -e "\n====================\nCopy $server_name.crt\n====================\n"
            scp -P $port "$dest_dir"/easy-rsa/pki/issued/"$server_name".crt "$server_path_ssh":~/keys
            echo -e "\n====================\nCopy $server_name.key\n====================\n"
            scp -P $port "$dest_dir"/easy-rsa/pki/private/"$server_name".key "$server_path_ssh":~/keys
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
    read -r -n 1 -p $'\n'"Continue or Skip (c|s) " cs
    case $cs in
        [Cc]*)
            read -r -e -p $'\n'"\nEnter the name of the client for which the certificate was issued: " client_name
            echo -e "\n====================\nCopy $client_name.crt\n====================\n"
            scp -P $port "$dest_dir"/easy-rsa/pki/issued/"$client_name".crt "$server_path_ssh":~/keys
            echo -e "\n====================\nCopy $client_name.key\n====================\n"
            scp -P $port "$dest_dir"/easy-rsa/pki/private/"$client_name".key "$server_path_ssh":~/keys
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
