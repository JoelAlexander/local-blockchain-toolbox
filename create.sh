#!/bin/bash

gethName=$(./install-geth.sh)
geth="$gethName/geth"
bootnode="$gethName/bootnode"

# Reads from the .env file, reusing values that it can, and creating what's needed.
bootnodeKey=$([ -f .env ] && awk -F'=' '/^BOOTNODE_KEY/ { print $2 }' .env | head -1)
bootnodeEnode=$([ -f .env ] && awk -F'=' '/^BOOTNODE_ENODE/ { print $2 }' .env | head -1)
if [ -z "${bootnodeKey}" ] && [ -z "${bootnodeEnode}" ]; then
  echo "Creating new bootnode."
  bootnodeKey=bootnode.key
  bootnodeEnode=$($bootnode -genkey bootnode.key -writeaddress)
  echo "BOOTNODE_KEY=$bootnodeKey" >> .env
  echo "BOOTNODE_ENODE=$bootnodeEnode" >> .env
elif [ -z "${bootnodeKey}" ] || [ -z "${bootnodeEnode}" ]; then
  echo "Invalid .env file, both BOOTNODE_KEY and BOOTNODE_ENODE should be set or unset"
fi

sealerPassword=$([ -f .env ] && awk -F'=' '/^SEALER_PASSWORD/ { print $2 }' .env | head -1)
if [ -z "${sealerPassword}" ]; then
  # TODO: The key is unlocked with no password, so is only as secure as the host password
  echo -n "Enter a password for the new sealing account: "
  read password
  sealerPassword=password.txt
  echo $password > password.txt
  echo "SEALER_PASSWORD=$sealerPassword" >> .env
fi

chainId=$([ -f .env ] && awk -F'=' '/^CHAIN_ID/ { print $2 }' .env | head -1)
genesisFile=$([ -f .env ] && awk -F'=' '/^GENESIS_FILE/ { print $2 }' .env | head -1)
sealerAccount=$([ -f .env ] && awk -F'=' '/^SEALER_ACCOUNT/ { print $2 }' .env | head -1)
sealerKeystore=$([ -f .env ] && awk -F'=' '/^SEALER_KEYSTORE/ { print $2 }' .env | head -1)
if [ -z "${genesisFile}" ]; then

  # TODO: All of the cases where we have a genesis file but we aren't a sealer
  newAccountOutput=$($geth account new --password $sealerPassword --datadir .)
  sealerAccount=$(echo $newAccountOutput | awk '{ print $11 }')
  sealerKeystore=$(realpath --relative-to=. $(echo $newAccountOutput | awk '{ print $18 }'))

  echo -n "Enter a chain ID for the blockchain genesis: "
  read chainId
  genesisFile=genesis.json
  node make-genesis.js $chainId $sealerAccount > genesis.json

  echo "CHAIN_ID=$chainId" >> .env
  echo "SEALER_ACCOUNT=$sealerAccount" >> .env
  echo "SEALER_KEYSTORE=$sealerKeystore" >> .env
  echo "GENESIS_FILE=$genesisFile" >> .env

fi



docker compose up
