#!/bin/bash

SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

# Check if there's an active profile with an attached chain
if [ -z "$PROFILE_CHAIN_NAME" ]; then
    echo "No active chain attached to the profile. Please attach a chain first."
    exit 1
fi

# Path to the ENS JSON file in the active chain directory
ENS_JSON_FILE="$LOCAL_DATA_DIR/chains/$PROFILE_CHAIN_NAME/ens.json"

# Check if the ENS JSON file exists
if [ ! -f "$ENS_JSON_FILE" ]; then
    echo "No ENS configuration found for the active chain. Please import ENS first."
    exit 1
fi

# List available ENS names
echo "Available ENS names:"
jq -r 'keys[]' "$ENS_JSON_FILE"

# Prompt the user to select an ENS name
read -p "Select an ENS name: " SELECTED_ENS

# Validate the selected ENS name
if ! jq -e --arg ensName "$SELECTED_ENS" '.[$ensName] // empty' "$ENS_JSON_FILE" > /dev/null; then
    echo "Invalid ENS name selected."
    exit 1
fi

# Update the profile.json with the selected ENS name
PROFILE_FILE="$ACTIVE_PROFILE_DIRECTORY/profile.json"
jq --arg ensName "$SELECTED_ENS" '.ens = $ensName' "$PROFILE_FILE" > temp.json && mv temp.json "$PROFILE_FILE"

echo "ENS '$SELECTED_ENS' has been attached to the active profile."
