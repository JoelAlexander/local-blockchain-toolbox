#!/bin/bash

SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

# Function to detach the active ENS
detach_active_ens() {
    if [ -z "$ENS_NAME" ]; then
        echo "No active ENS to detach."
        return 1
    fi

    jq 'del(.ens)' "$ACTIVE_PROFILE_FILE" > temp.json && mv temp.json "$ACTIVE_PROFILE_FILE"
    echo "ENS $ENS_NAME has been detached from the active profile."
}

# Main logic
if ! detach_active_ens; then
    echo "Failed to detach ENS. Exiting."
    exit 1
fi

echo "ENS successfully detached."
