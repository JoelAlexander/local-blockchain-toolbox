#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

echo -e "Blockchain Node Manager Status Report\n====================================="

# Display the chain name
echo -e "\nChain Name: $PROFILE_CHAIN_NAME"

# Check if genesis file exists and parse required information
if [ -f "$PROFILE_CHAIN_GENESIS_FILE" ]; then
    echo -e "\nGenesis File for chain $PROFILE_CHAIN_NAME:"
    echo "Chain ID: $PROFILE_CHAIN_ID"
    
    echo "Alloc Addresses and Balances:"
    jq -r '.alloc | to_entries[] | "\(.key): balance \(.value.balance)"' "$PROFILE_CHAIN_GENESIS_FILE"

    echo "Original Sealing Node Address: $PROFILE_CHAIN_SEALER_ADDRESS"
else
    echo "Genesis file for chain $PROFILE_CHAIN_NAME not found."
fi

# Check RPC domain status
echo -e "\nRPC Domain: $PROFILE_CHAIN_RPC_DOMAIN"
if ping -c 1 "$PROFILE_CHAIN_RPC_DOMAIN" &> /dev/null; then
    echo "RPC is online."
else
    echo "RPC is offline."
fi

# Display linked accounts
echo -e "\nLinked Accounts:"
if [ ${#PROFILE_LINKED_ACCOUNTS[@]} -eq 0 ]; then
    echo "No linked accounts."
else
    for account in "${PROFILE_LINKED_ACCOUNTS[@]}"; do
        echo -n "$account"
        [ "$account" == "$PROFILE_ACTIVE_ACCOUNT" ] && echo " (active)" || echo
        keypath=$($SCRIPT_DIR/get-keystore.sh $account)
        if [ -f "$keypath" ]; then
            echo "Keystore found: $keypath"
            balance=$(npx hardhat getBalance --account $account)
            echo "Balance: $balance"
        else
            echo "Keystore not found for account $account"
        fi
    done
fi

echo -e "\nBoonode Enode: $DEFAULT_BOOTNODE_ENODE"

echo -e "\nStatus report completed."
