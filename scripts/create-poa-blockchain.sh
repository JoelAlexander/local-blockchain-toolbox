#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"
gethPath=$($SCRIPT_DIR/install-geth.sh)
geth="$gethPath/geth"
clef="$gethPath/clef"

# Prompt for chain ID
echo -n "Enter a name for this blockchain: "
read chainName

chainDir="$LOCAL_DATA_DIR/chains/$chainName"
keystoreDir="$LOCAL_DATA_DIR/keystore"
clefDir="$chainDir/clef"

if [ -d "$chainDir" ]; then
    echo "Chain with name $chainName already exists: $chainDir" && exit 1
fi

mkdir -p $chainDir
mkdir -p $clefDir

# Prompt for chain ID
echo -n "Enter a chain ID for the blockchain: "
read chainId

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

# Create new account and store in the specified keystore directory
echo "Creating new account..."
passwordInput="$password\n$password"
newAccountOutput=$(printf "$passwordInput" | $geth account new --keystore $keystoreDir)

# Extract and store account details
sealerAccount=$(echo $newAccountOutput | grep -Po 'Public address of the key: \K0x[a-fA-F0-9]+')
sealerKeystorePath=$(echo $newAccountOutput | grep -Po 'Path of the secret key file: \K[^ ]+')

echo $newAccountOutput
echo $keystoreDir
echo $sealerAccount
echo $sealerKeystorePath
# Initialize Clef for this chain with chain ID
echo "Initializing Clef for chain: $chainName with chain ID: $chainId"
$clef --keystore $keystoreDir --configdir $clefDir --chainid $chainId --suppress-bootwarn init

genesis=$(npx hardhat makeGenesis\
  --chain-id $chainId\
  --sealer-address $sealerAccount\
  --alloc-address $sealerAccount)

echo $genesis > $chainDir/genesis.json

#$SCRIPT_DIR/create-bootnode.sh $chainName
