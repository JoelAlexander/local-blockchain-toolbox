#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

gethPath=$($SCRIPT_DIR/install-geth.sh)
geth="$gethPath/geth"

echo -n "Enter a name for the blockchain: "
read chainName

chainDir="$LOCAL_DATA_DIR/chains/$chainName"
keystoreDir="$LOCAL_DATA_DIR/keystore"

# Check if the chain directory already exists
if [ -d "$chainDir" ]; then
    echo "Chain with name $chainName already exists: $chainDir" && exit 1
fi

# Create chain directory
mkdir -p $chainDir

# Prompt for chain ID
echo -n "Enter a chain ID for the blockchain: "
read chainId

# Function to get account address from keystore file
get_account_address() {
    local keystoreFile=$1
    local addressInFilename=${keystoreFile##*--}
    echo $addressInFilename
}

# Helper function to select account
select_account() {
    local accountType=$1
    local partialAddress=${2:-}

    echo "Selecting $accountType account..."
    KEYS=

    select KEYSTORE_FILE in $KEYS; do
        if [ -n "$KEYSTORE_FILE" ]; then
            
            echo "Selected $accountType account: $selectedAddress"
            break
        else
            echo "Please select a valid keystore file."
        fi
    done

    echo $selectedAddress
}

# Select sealer account
echo "Selecting sealer account..."
keystoreFile=$($SCRIPT_DIR/get-keystore.sh $1)
sealerAddress=$(get_account_address "$keystoreFile")
echo "Sealer address: $sealerAddress"

# Select alloc account
echo "Selecting alloc account..."
keystoreFile=$($SCRIPT_DIR/get-keystore.sh $1)
allocAddress=$(get_account_address "$keystoreFile")
echo "Alloc address: $allocAddress"

# Create the genesis block
echo "Creating genesis block..."
genesis=$(npx hardhat makeGenesis\
  --chain-id $chainId\
  --sealer-address $sealerAddress\
  --alloc-address $allocAddress)

echo $genesis > $chainDir/genesis.json
