#!/bin/bash

SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

# Function to remove a specified ENS
remove_ens() {
    local ens_name=$1

    if [ -z "$ens_name" ]; then
        echo "No ENS name provided. Available ENS names:"
        jq -r 'keys[]' "$ENS_JSON_FILE"
        read -p "Enter the ENS name to remove: " ens_name
    fi

    if ! jq -e --arg ensName "$ens_name" '.[$ensName] // empty' "$ENS_JSON_FILE" > /dev/null; then
        echo "ENS name '$ens_name' not found."
        return 1
    fi

    jq --arg ensName "$ens_name" 'del(.[$ensName])' "$ENS_JSON_FILE" > temp.json && mv temp.json "$ENS_JSON_FILE"
    echo "ENS $ens_name has been removed."
}

# Main logic
ENS_NAME=${1:-""}
if ! remove_ens "$ENS_NAME"; then
    echo "Failed to remove ENS. Exiting."
    exit 1
fi

echo "ENS successfully removed."
