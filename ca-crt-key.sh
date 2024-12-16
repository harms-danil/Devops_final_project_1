#!/bin/bash

# Activate the option that interrupts script execution if any command terminates with a non-zero status
set -e

# Vars
port=1985
host="harms-devops.ru"
dest_dir="/home/harms"
username="harms"

# Request the server part where to copy the keys and certificate
read -r -e -p "Enter the SUB_name server for path (format: username@'SUB'.hostname): " sub_name
server_path_ssh="$username@$sub_name.$host"
server_name="$sub_name.$host"
echo -e "\n$server_name"
echo -e "\n$server_path_ssh"

# Select actions with certificates and keys menu
while true; do
    echo -e "\n--------------------------\n"
    echo -e "[1] Create pair crt and key\n"
    echo -e "[2] Copy ca.srt\n"
    echo -e "[3] Copy server certificate and key\n"
    echo -e "[4] Copy client certificate and key\n"
    echo -e "[5] Copy server certificate to monitoring server\n"
    echo -e "[6] Exit\n"
    echo -e "--------------------------\n"
    read -r -n 1 -p "Select an action: " certificate

    case $certificate in
	# Create pair crt and key
	1)
	echo -e "\n====================\nCreate crt and key \n===================="
	if [ -f "$dest_dir"/easy-rsa/pki/private/"$server_name".key ]; then
		echo -e "\nFile $dest_dir/easy-rsa/pki/issued/$server_name found!\nDeleting it..."
		rm -rf "$dest_dir"/easy-rsa/pki/private/"$server_name".key
	fi
	if [ -f $dest_dir/easy-rsa/pki/issued/"$server_name".crt ]; then
		echo -e "\nFile $dest_dir/easy-rsa/pki/private/$server_name found!\nDeleting it..."
		rm -rf $dest_dir/easy-rsa/pki/issued/"$server_name".crt
	fi
	cd $dest_dir/easy-rsa
	./easyrsa gen-req "$server_name" nopass
	./easyrsa sign-req server "$server_name"
	# remove req
	rm $dest_dir/easy-rsa/pki/reqs/"$server_name.req"
	echo -e "\nDONE"
	;;

	# Copy ca.srt
	2)
	echo -e "\n====================\nCopy ca.crt\n===================="
	scp -P $port "$dest_dir"/easy-rsa/pki/ca.crt  "$server_path_ssh":~/keys
	echo -e "\nDONE"
	break
	;;

	# Copy server certificate and key
	3)
	echo -e "\n====================\nCopy server certificate and key\n===================="
	echo -e "\n====================\nCopy $server_name.crt\n====================\n"
	scp -P $port "$dest_dir"/easy-rsa/pki/issued/"$server_name".crt "$server_path_ssh":~/keys
	echo -e "\n====================\nCopy $server_name.key\n====================\n"
	scp -P $port "$dest_dir"/easy-rsa/pki/private/"$server_name".key "$server_path_ssh":~/keys
	echo -e "\nDONE\n"
	break
	;;

	# Copy client certificate and key
	4)
	echo -e "\n====================\nCopy client certificate and key\n===================="
	read -r -e -p $'\n'"\nEnter the name of the client for which the certificate was issued: " client_name
	echo -e "\n====================\nCopy $client_name.crt\n===================="
	scp -P $port "$dest_dir"/easy-rsa/pki/issued/"$client_name".crt "$server_path_ssh":~/keys
	echo -e "\n====================\nCopy $client_name.key\n===================="
	scp -P $port "$dest_dir"/easy-rsa/pki/private/"$client_name".key "$server_path_ssh":~/keys
	echo -e "\nDONE"
	break
	;;

	# Copy server certificate to monitoring server
	5)
	echo -e "\n====================\nCopy server certificate to monitoring server\n===================="
	echo -e "\n====================\nCopy $server_name.crt\n====================\n"
	scp -P $port "$dest_dir"/easy-rsa/pki/issued/"$server_name".crt "$username@monitor.$hostname":~/keys
	echo -e "\nDONE\n"
	break
	;;

	# exit
	6) echo -e "\n"
		break
		;;
	esac
done