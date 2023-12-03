#!/bin/bash

# Source the local environment script to set environment variables
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

# Ensure Geth is installed using install-geth.sh
GETH_PATH=$(${SCRIPT_DIR}/install-geth.sh)

# Define the path to the clef tool
CLEF="$GETH_PATH/clef"

# Check if clef exists
if [ ! -f "$CLEF" ]; then
    echo "clef tool not found at $CLEF"
    exit 1
fi

# Check for required arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <password>"
    exit 1
fi

PASSWORD=$1

# Run clef to create a new account and extract the account address
NEW_ACCOUNT_OUTPUT=$(echo $PASSWORD | $CLEF newaccount --keystore "$LOCAL_DATA_DIR/keystore" --suppress-bootwarn)
NEW_ACCOUNT_ADDRESS=$(echo "$NEW_ACCOUNT_OUTPUT" | grep -o 'Generated account \S*' | awk '{print $3}')

echo $NEW_ACCOUNT_ADDRESS
