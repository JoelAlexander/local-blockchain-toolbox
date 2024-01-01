#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

# Get the chain path using get-chain.sh
CHAIN_PATH=$($SCRIPT_DIR/get-chain.sh $1)
if [ $? -eq 1 ]; then
    echo "Chain not found."
    exit 1
fi

# Check if the directory exists
if [ -z "$CHAIN_PATH" ]; then
    echo "Invalid chain directory selected"
    exit 1
fi

echo "Chain Information for: $(basename $CHAIN_PATH)"

# Extract sealing account
SEALER_ACCOUNT=$(jq -r '.extraData|split("x")[1][64:104]' $CHAIN_PATH/genesis.json)
echo "Sealer Account: $SEALER_ACCOUNT"
KEYSTORE_PATH=$($SCRIPT_DIR/get-keystore.sh $SEALER_ACCOUNT)
if [ -f "$KEYSTORE_PATH" ]; then
    echo "Sealer Account Keystore is present at: $KEYSTORE_PATH"
else
    echo "Sealer Account Keystore is not present."
fi

# List allocated accounts
echo "Allocated Accounts:"
jq -r '.alloc | to_entries[] | "\(.key)"' $CHAIN_PATH/genesis.json | while read ACCOUNT; do
    echo -n "$ACCOUNT"
    KEYSTORE_PATH=$($SCRIPT_DIR/get-keystore.sh $ACCOUNT)
    if [ -f "$KEYSTORE_PATH" ]; then
        echo " (Keystore present)"
        # Optionally, add balance checking here if you have the necessary setup
        # BALANCE=$(npx hardhat --network yourNetworkName getBalance --account $ACCOUNT)
        # echo " Balance: $BALANCE"
    else
        echo " (Keystore not present)"
    fi
done
