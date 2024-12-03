#!/bin/bash

# First argument: Client identifier
KEY_DIR=/etc/openvpn/clients/keys
OUTPUT_DIR=/etc/openvpn/clients/files
BASE_CONFIG=/etc/openvpn/clients/base.conf

cat ${BASE_CONFIG} \
    <(echo -e '<ca>') \
    ${KEY_DIR}/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    ${KEY_DIR}/${1}.crt \
    <(echo -e '</cert>\n<key>') \
    ${KEY_DIR}/${1}.key \
    <(echo -e '</key>\n<tls-crypt>') \
    ${KEY_DIR}/ta.key \
    <(echo -e '</tls-crypt>') \
> ${OUTPUT_DIR}/${1}.ovpn

echo -e "\nClient config create: ${OUTPUT_DIR}/${1}.ovpn\n"