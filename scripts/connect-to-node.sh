#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

HOSTNAME=$1
SCRIPT_PATH=$2

# Function to get username from a node JSON file
get_username() {
    local hostname=$1
    local node_file="${LOCAL_DATA_DIR}/nodes/${hostname}.json"
    if [ -f "$node_file" ]; then
        echo $(jq -r '.username' "$node_file")
    else
        echo ""
    fi
}

# Create HOSTNAME_LOCAL with .local suffix
HOSTNAME_LOCAL="${HOSTNAME}.local"

echo "${LOCAL_DATA_DIR}/nodes/${HOSTNAME}.json"

# Get the username from the node file
USERNAME=$(get_username "$HOSTNAME")
if [ -z "$USERNAME" ]; then
    echo "Username not found for $HOSTNAME. Check the node's JSON file."
    exit 1
fi

echo "Waiting for the host $HOSTNAME_LOCAL to be reachable on the network..."
while ! ping -c 1 -W 1 $HOSTNAME_LOCAL &> /dev/null; do
    sleep 1
done

echo "Host $HOSTNAME_LOCAL is now reachable. Attempting to SSH into the host..."
ssh-keyscan -H $HOSTNAME_LOCAL >> ~/.ssh/known_hosts 2>/dev/null

echo "Select an SSH key to use for connection:"
select SSH_KEY_PATH in "${LOCAL_DATA_DIR}/.ssh/"* "Enter a different path"; do
    if [ "$SSH_KEY_PATH" == "Enter a different path" ]; then
        read -p "Enter the full path to your SSH key: " SSH_KEY_PATH
    fi
    if [ -n "$SSH_KEY_PATH" ]; then
        break
    else
        echo "Please select a valid key."
    fi
done

if [ -n "$2" ]; then
    SCRIPT_PATH=$2
    echo "Executing script $SCRIPT_PATH on the host $HOSTNAME_LOCAL..."
    ssh -i "$SSH_KEY_PATH" $USERNAME@$HOSTNAME_LOCAL 'bash -s' < "$SCRIPT_PATH"
else
    ssh -i "$SSH_KEY_PATH" $USERNAME@$HOSTNAME_LOCAL
fi
