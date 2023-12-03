#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

KEYSTORE_DIR="$LOCAL_DATA_DIR/keystore"

MATCHING_FILES=()

# Populate MATCHING_FILES with all files if no argument is provided
if [ $# -eq 0 ]; then
    MATCHING_FILES=("$KEYSTORE_DIR"/*)
else
    PARTIAL_ADDRESS=${1,,} # Convert to lowercase
    PARTIAL_ADDRESS=${PARTIAL_ADDRESS#0x} # Remove '0x' prefix if present

    # Loop over files and match with the beginning of the address
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

# Handle file matching results
if [ ${#MATCHING_FILES[@]} -eq 0 ]; then
    echo "No keystore files found."
    exit 1
elif [ ${#MATCHING_FILES[@]} -eq 1 ]; then
    echo "${MATCHING_FILES[0]}"
else
    select FILE in "${MATCHING_FILES[@]}"; do
        echo "$FILE"
        break
    done
fi
