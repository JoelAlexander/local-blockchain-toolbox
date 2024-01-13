#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

echo -e "\033[1mBlockchain Node Manager Status Report\033[0m\n====================================="

# Display the chain name
echo -e "\n\033[1mChain Name:\033[0m $PROFILE_CHAIN_NAME"

# Check if genesis file exists and parse required information
if [ -f "$PROFILE_CHAIN_GENESIS_FILE" ]; then
    echo -e "\n\033[1mGenesis File for chain $PROFILE_CHAIN_NAME:\033[0m"
    echo "Chain ID: $PROFILE_CHAIN_ID"
    
    echo "Alloc Addresses and Balances:"
    jq -r '.alloc | to_entries[] | "\(.key): balance \(.value.balance)"' "$PROFILE_CHAIN_GENESIS_FILE"

    echo "Original Sealing Node Address: $PROFILE_CHAIN_SEALER_ADDRESS"
else
    echo "Genesis file for chain $PROFILE_CHAIN_NAME not found."
fi

# Check RPC domain status
echo -e "\n\033[1mRPC Domain:\033[0m $PROFILE_CHAIN_RPC_DOMAIN"
if ping -c 1 "$PROFILE_CHAIN_RPC_DOMAIN" &> /dev/null; then
    echo "RPC is online."
else
    echo "RPC is offline."
fi

# Display linked accounts
echo -e "\n\033[1mLinked Accounts:\033[0m"
if [ ${#PROFILE_LINKED_ACCOUNTS[@]} -eq 0 ]; then
    echo "No linked accounts."
else
    for account in "${PROFILE_LINKED_ACCOUNTS[@]}"; do
        echo -n "0x$account"
        [ "$account" == "$PROFILE_ACTIVE_ACCOUNT" ] && echo " (active)" || echo
        keypath=$($SCRIPT_DIR/get-keystore.sh $account)
        if [ -f "$keypath" ]; then
            echo "Keystore found: $keypath"
            balance=$(npx hardhat getBalance 0x$account)
            echo "Balance: $balance"
        else
            echo "Keystore not found for account $account"
        fi
    done
fi

# Display ENS information
echo -e "\n\033[1mAttached ENS:\033[0m"
if [ -n "$ENS_NAME" ]; then
    echo "$ENS_NAME"
    if [ -n "$ENS_ADDRESS" ]; then
        echo "ENS Address: $ENS_ADDRESS"
    fi
else
    echo "No ENS attached."
fi

echo -e "\nBootnode Enode: $DEFAULT_BOOTNODE_ENODE"

echo -e "\nStatus report completed."
