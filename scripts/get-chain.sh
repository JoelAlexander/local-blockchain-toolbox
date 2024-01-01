#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

CHAINS_DIR="$LOCAL_DATA_DIR/chains"

# Function to list and select chains
list_and_select_chains() {
    MATCHING_CHAINS=()

    shopt -s nullglob
    for DIR in "$CHAINS_DIR"/*; do
        if [ -d "$DIR" ]; then
            MATCHING_CHAINS+=("$DIR")
        fi
    done
    shopt -u nullglob

    if [ ${#MATCHING_CHAINS[@]} -eq 0 ]; then
        echo "No chains found." >&2
        exit 1
    elif [ ${#MATCHING_CHAINS[@]} -eq 1 ]; then
        echo "${MATCHING_CHAINS[0]}"
    else
        echo "Select a chain:" >&2
        select CHAIN in "${MATCHING_CHAINS[@]}"; do
            if [ -n "$CHAIN" ]; then
                echo "$CHAIN"
                break
            else
                echo "Invalid selection. Please try again." >&2
            fi
        done
    fi
}

# Main menu for the script
echo "Selecting a chain:" >&2
echo "1) Select an existing blockchain" >&2
echo "2) Create a new blockchain" >&2

read -p "Enter your choice (1/2): " choice >&2

case $choice in
    1)
        list_and_select_chains
        ;;
    2)
        $SCRIPT_DIR/create-poa-blockchain.sh
        ;;
    *)
        echo "Invalid choice. Exiting." >&2
        exit 1
        ;;
esac
