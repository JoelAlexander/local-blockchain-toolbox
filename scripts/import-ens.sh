#!/bin/bash

SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

# Function to validate Ethereum address (basic validation)
is_valid_ethereum_address() {
    if [[ $1 =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Ensure ENS deployment address is passed as an argument
if [ $# -lt 1 ]; then
    echo "Usage: $0 <ENS deployment address>"
    exit 1
fi

ENS_DEPLOYMENT_ADDRESS=$1

# Validate the ENS deployment address
if ! is_valid_ethereum_address "$ENS_DEPLOYMENT_ADDRESS"; then
    echo "Invalid Ethereum address: $ENS_DEPLOYMENT_ADDRESS"
    exit 1
fi

# Ensure there's an active profile with an attached chain
if [ -z "$PROFILE_CHAIN_NAME" ]; then
    echo "No active chain attached to the profile. Please attach a chain first."
    exit 1
fi

# Prompt for ENS name
read -p "Enter ENS name to import (default if blank): " ENS_NAME
ENS_NAME=${ENS_NAME:-default}

# Path to the ENS JSON file in the active chain directory
ENS_JSON_FILE="$LOCAL_DATA_DIR/chains/$PROFILE_CHAIN_NAME/ens.json"

# Ensure the ENS JSON file exists
if [ ! -f "$ENS_JSON_FILE" ]; then
    echo "{}" > "$ENS_JSON_FILE"
fi

# Check for conflicts and prompt until a unique name is given
while jq -e --arg ensName "$ENS_NAME" '.[$ensName] // empty' "$ENS_JSON_FILE" > /dev/null; do
    read -p "ENS name already exists. Enter a unique ENS name: " ENS_NAME
    ENS_NAME=${ENS_NAME:-default}
done

# Add ENS to the ens.json file
jq --arg ensName "$ENS_NAME" --arg ensAddress "$ENS_DEPLOYMENT_ADDRESS" '.[$ensName] = $ensAddress' "$ENS_JSON_FILE" > temp.json && mv temp.json "$ENS_JSON_FILE"

echo "ENS imported successfully: $ENS_NAME -> $ENS_DEPLOYMENT_ADDRESS"
