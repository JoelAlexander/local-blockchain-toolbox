#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

echo -n "Enter a name for the blockchain: " >&2
read chainName

chainDir="$LOCAL_DATA_DIR/chains/$chainName"
keystoreDir="$LOCAL_DATA_DIR/keystore"

# Check if the chain directory already exists
if [ -d "$chainDir" ]; then
    echo "Chain with name $chainName already exists: $chainDir" >&2
    exit 1
fi

# Create chain directory
mkdir -p $chainDir

# Prompt for chain ID
echo -n "Enter a chain ID for the blockchain: " >&2
read chainId

# Function to get account address from keystore file
get_account_address() {
    local keystoreFile=$1
    local addressInFilename=${keystoreFile##*--}
    echo $addressInFilename
}

# Function to repeatedly prompt for keystore file until a valid selection is made
prompt_for_keystore() {
    local keystoreFile
    local success=false

    while [ "$success" = false ]; do
        keystoreFile=$($SCRIPT_DIR/get-keystore.sh)
        if [ $? -eq 0 ]; then
            success=true
            echo $keystoreFile
        else
            echo "Invalid selection. Please try again." >&2
        fi
    done
}

# Select sealer account
echo "Selecting sealer account..." >&2
keystoreFile=$(prompt_for_keystore)
sealerAddress=$(get_account_address "$keystoreFile")
echo "Sealer address: $sealerAddress" >&2

# Select alloc account
echo "Selecting alloc account..." >&2
keystoreFile=$(prompt_for_keystore)
allocAddress=$(get_account_address "$keystoreFile")
echo "Alloc address: $allocAddress" >&2

# Create the genesis block
echo "Creating genesis block..." >&2
genesis=$(npx hardhat makeGenesis \
  --chain-id $chainId \
  --sealer-address $sealerAddress \
  --alloc-address $allocAddress)

echo $genesis > $chainDir/genesis.json

echo $chainDir
