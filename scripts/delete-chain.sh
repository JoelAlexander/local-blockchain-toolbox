#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

CHAINS_DIR="$LOCAL_DATA_DIR/chains"
PROFILES_DIR="$LOCAL_DATA_DIR/profiles"

# Function to list and select chains
select_chain() {
    echo "Select a chain to delete:"
    select chain in "$CHAINS_DIR"/*; do
        if [ -n "$chain" ]; then
            echo "$chain"
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
}

chain_to_delete=$(select_chain)
chain_name=$(basename "$chain_to_delete")

for profile in "$PROFILES_DIR"/*; do
    if jq -e --arg chain "$chain_name" '.chain == $chain' "$profile/profile.json" > /dev/null; then
        echo "Chain '$chain_name' is in use by profile '$(basename "$profile")'. Cannot delete."
        exit 1
    fi
done

rm -rf "$chain_to_delete"
echo "Chain deleted successfully."
