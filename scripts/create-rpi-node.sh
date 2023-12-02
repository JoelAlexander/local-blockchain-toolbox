#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

HOSTNAME=$(openssl rand -hex 4)
echo "Beginning to create new node: $HOSTNAME"
read -p "Enter Wi-Fi SSID: " WIFI_SSID
read -p "Enter Wi-Fi Password: " WIFI_PASSWORD
read -p "Enter new username: " NEW_USERNAME
NEW_USERNAME=${NEW_USERNAME:-ubuntu}

# SSH Key Setup
read -p "Do you want to use an existing SSH key or generate a new one? (existing/new): " SSH_KEY_CHOICE

if [ "$SSH_KEY_CHOICE" == "new" ]; then
    SSH_DIR="${LOCAL_DATA_DIR}/.ssh"
    mkdir -p $SSH_DIR

    KEY_NAME="${NEW_USERNAME}_${HOSTNAME}"
    KEY_PATH="$SSH_DIR/$KEY_NAME"
    echo "Generating a new SSH key..."
    ssh-keygen -t rsa -b 2048 -f $KEY_PATH -q -N ""
    PUB_KEY=$(cat "$KEY_PATH.pub")
    echo "New SSH key generated at $KEY_PATH"
else
    read -p "Enter the path to your existing SSH public key: " EXISTING_KEY_PATH
    PUB_KEY=$(cat "$EXISTING_KEY_PATH")
    echo "Using the existing SSH key"
fi

sudo ${SCRIPT_DIR}/create-node-sd.sh "$HOSTNAME" "$PUB_KEY" "$WIFI_SSID" "$WIFI_PASSWORD" "$NEW_USERNAME"
${SCRIPT_DIR}/update-node-record.sh "$HOSTNAME" "username" "$NEW_USERNAME"

echo "You can now remove the SD card, put it in your Raspberry Pi and power on"

read -p "Do you want to boot and set up the node now? (y/n): " BOOT_NOW
if [[ $BOOT_NOW != "y" ]]; then
    echo "You can boot and set up the node later."
    exit 0
fi

${SCRIPT_DIR}/connect-to-node.sh $HOSTNAME
