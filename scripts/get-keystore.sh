#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

KEYSTORE_DIR="$LOCAL_DATA_DIR/keystore"

# Function to list and select keystore files
list_and_select_keystores() {
    MATCHING_FILES=()
    
    shopt -s nullglob
    if [ $# -eq 0 ]; then
        # If no argument is provided, populate MATCHING_FILES with all files
        MATCHING_FILES=("$KEYSTORE_DIR"/*)
    else
        PARTIAL_ADDRESS=${1,,} # Convert to lowercase
        PARTIAL_ADDRESS=${PARTIAL_ADDRESS#0x} # Remove '0x' prefix if present

        for FILE in $KEYSTORE_DIR/*; do
            # Extract the Ethereum address part from the filename
            FILENAME=$(basename "$FILE")
            ADDRESS_IN_FILENAME=${FILENAME##*--}

            # Check if the address in the filename starts with the partial address
            if [[ $ADDRESS_IN_FILENAME =~ ^$PARTIAL_ADDRESS ]]; then
                MATCHING_FILES+=("$FILE")
            fi
        done
    fi
    shopt -u nullglob

    if [ ${#MATCHING_FILES[@]} -eq 0 ]; then
        echo "No matching keystore files found." >&2
        exit 1
    elif [ ${#MATCHING_FILES[@]} -eq 1 ]; then
        echo "${MATCHING_FILES[0]}"
    else
        echo "Select a keystore file:" >&2
        select FILE in "${MATCHING_FILES[@]}"; do
            if [ -n "$FILE" ]; then
                echo "$FILE"
                break
            else
                echo "Invalid selection. Please try again." >&2
            fi
        done
    fi
}

if [ $# -eq 1 ]; then
    list_and_select_keystores $1
else
    # Main menu for the script
    echo "Select an action:" >&2
    echo "1) Use existing account" >&2
    echo "2) Create new account" >&2

    read -p "Enter your choice (1/2): " choice >&2

    case $choice in
        1)
            list_and_select_keystores
            ;;
        2)
            # Create new account
            NEW_ACCOUNT_ADDRESS=$($SCRIPT_DIR/create-account.sh)
            if [ $? -ne 0 ]; then
                echo "Failed to create new account." >&2
                exit 1
            else
                echo "New account created: $NEW_ACCOUNT_ADDRESS" >&2
                # Should be the only one with this address
                echo $(list_and_select_keystores $NEW_ACCOUNT_ADDRESS)
            fi
            ;;
        *)
            echo "Invalid choice. Exiting." >&2
            exit 1
            ;;
    esac
fi