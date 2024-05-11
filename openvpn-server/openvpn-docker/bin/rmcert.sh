#!/bin/bash
#VERSION 0.3 by d3vilh@github.com aka Mr. Philipp
# Exit immediately if a command exits with a non-zero status
set -e

#Variables
CERT_NAME=$1
CERT_SERIAL=$2
EASY_RSA=/usr/share/easy-rsa
OPENVPN_DIR=/etc/openvpn
echo 'EasyRSA path: $EASY_RSA OVPN path: $OPENVPN_DIR'
OVPN_FILE_PATH="$OPENVPN_DIR/clients/$CERT_NAME.ovpn"
QR_CODE_PATH="$OPENVPN_DIR/clients/$CERT_NAME.png" # 2FA QR code
OATH_SECRETS="$OPENVPN_DIR/clients/oath.secrets"   # 2FA secrets file
INDEX="$EASY_RSA/pki/index.txt"

echo "Removing user: $CERT_NAME with Serial: $CERT_SERIAL"

# Define if cert is valid or revoked
STATUS_CH=$(grep -e ${CERT_NAME}$ -e${CERT_NAME}/ ${INDEX} | awk '{print $1}' | tr -d '\n')
if [[ $STATUS_CH = "V" ]]; then
    echo "Cert is VALID\nShould not remove: $CERT_NAME with serial: $CERT_SERIAL\nExiting..."
    exit 1
else
    echo "Cert is REVOKED\nContinue to remove: $CERT_NAME with serial: $CERT_SERIAL"
fi

# Check if the user has two certificates in index.txt
if [[ $(cat $INDEX | grep -c "/CN=$CERT_NAME/") -eq 2 ]]; then
    echo "Removing renewed certificate..."
    sed -i'.bak' "/${CERT_SERIAL}/d" $INDEX
    # removing *.ovpn file because it has old certificate
    rm -f $OVPN_FILE_PATH
    
    echo 'Generating New .ovpn file...'
    CA="$(cat $EASY_RSA/pki/ca.crt )"
    CERT="$(cat $EASY_RSA/pki/issued/${CERT_NAME}.crt | grep -zEo -e '-----BEGIN CERTIFICATE-----(\n|.)*-----END CERTIFICATE-----' | tr -d '\0')"
    KEY="$(cat $EASY_RSA/pki/private/${CERT_NAME}.key)"
    TLS_AUTH="$(cat $EASY_RSA/pki/ta.key)"
    echo "$(cat $OPENVPN_DIR/config/client.conf)
<ca>
$CA
</ca>
<cert>
$CERT
</cert>
<key>
$KEY
</key>
<tls-auth>
$TLS_AUTH
</tls-auth>
" > "$OVPN_FILE_PATH"
    echo "New .ovpn file created."

else
    echo "Removing certificate...\nRemoving *.ovpn file" 
    rm -f $OVPN_FILE_PATH
    rm -f $QR_CODE_PATH
    # Remove user from oath.secrets
    if [ -f "$OATH_SECRETS" ]; then
      sed -i'.bak' "/${TFA_NAME}/d" "$OATH_SECRETS"
    else
      echo "No $OATH_SECRETS nothing to remove"
    fi
    # Removing the user from the list following the serial number
    sed -i'.bak' "/${CERT_SERIAL}/d" $INDEX
    echo "Database fixed."
fi

echo 'Remove done!\nIf you want to disconnect the user please restart the OpenVPN service or container.'
