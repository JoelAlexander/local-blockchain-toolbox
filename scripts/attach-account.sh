#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

# Check for required arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <chain_name> [account_address]"
    exit 1
fi

CHAIN_NAME=$1
ACCOUNT_ADDRESS=${2:-}

CHAIN_DIR="$LOCAL_DATA_DIR/chains/$CHAIN_NAME"
GENESIS_FILE="$CHAIN_DIR/genesis.json"

if [ ! -d "$CHAIN_DIR" ] || [ ! -f "$GENESIS_FILE" ]; then
    echo "Error: Chain '$CHAIN_NAME' does not exist or missing genesis.json file."
    exit 1
fi

if [ -n "$ACCOUNT_ADDRESS" ]; then
    # Get the keystore file for the provided address
    KEYSTORE_FILE=$(${SCRIPT_DIR}/get-keystore.sh $ACCOUNT_ADDRESS)

    if [ -n "$KEYSTORE_FILE" ]; then
        echo "Found keystore file: $KEYSTORE_FILE"
        echo "Please enter the password for the existing account."
        prompt_password
        # Logic to attach the account to Clef for the specified chain
    fi
else
    echo "No account address provided. Creating a new account..."
    echo "Please write down your password before continuing."
    prompt_password
    ${SCRIPT_DIR}/create-account.sh $password
    # Logic to attach the newly created account to Clef for the specified chain
fi

# Initialize Clef for this chain with chain ID
#echo "Initializing Clef for chain: $chainName with chain ID: $chainId"
#$clef --keystore $keystoreDir --configdir $CLEF_DIR --chainid $chainId --suppress-bootwarn init

