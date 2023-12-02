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

# Function to prompt for password
prompt_password() {
    while true; do
        read -s -p "Enter a new password (10 or more characters): " password
        echo
        read -s -p "Confirm your password: " password_confirm
        echo

        if [ "$password" != "$password_confirm" ]; then
            echo "Passwords do not match. Please try again."
        elif [ ${#password} -lt 10 ]; then
            echo "Password is less than 10 characters. Please try again."
        else
            break
        fi
    done
}

echo "Please write down your password before continuing."
prompt_password

# Run clef to create a new account with the entered password
echo $password | $CLEF newaccount --keystore "$LOCAL_DATA_DIR/keystore" --suppress-bootwarn

echo "Account creation complete."
