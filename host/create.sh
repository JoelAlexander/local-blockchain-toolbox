#!/bin/bash

scriptPath=$(dirname $(realpath $0))
localBlockchainPath=$($scriptPath/get-blockchain-directory.sh)

gethName=$($scriptPath/install-geth.sh)
geth="$localBlockchainPath/$gethName/geth"
bootnode="$localBlockchainPath/$gethName/bootnode"

# Reads from the .env file, reusing values that it can, and creating what's needed.
bootnodeKey=$($scriptPath/get-local-blockchain-env.sh BOOTNODE_KEY)
bootnodeEnode=$($scriptPath/get-local-blockchain-env.sh BOOTNODE_ENODE)
if [ -z "${bootnodeKey}" ] && [ -z "${bootnodeEnode}" ]; then
  echo "Creating new bootnode."
  bootnodeKey=bootnode.key
  bootnodeEnode=$($bootnode -genkey $localBlockchainPath/bootnode.key -writeaddress)
  echo "BOOTNODE_KEY=$bootnodeKey" >> $localBlockchainPath/.env
  echo "BOOTNODE_ENODE=$bootnodeEnode" >> $localBlockchainPath/.env
elif [ -z "${bootnodeKey}" ] || [ -z "${bootnodeEnode}" ]; then
  echo "Invalid .env file, both BOOTNODE_KEY and BOOTNODE_ENODE should be set or unset"
fi

sealerPassword=$($scriptPath/get-local-blockchain-env.sh SEALER_PASSWORD)
if [ -z "${sealerPassword}" ]; then
  # TODO: The key is unlocked with no password, so is only as secure as the host password
  echo -n "Enter a password for the new sealing account: "
  read password
  sealerPassword=password.txt
  echo $password > $localBlockchainPath/$sealerPassword
  echo "SEALER_PASSWORD=$sealerPassword" >> $localBlockchainPath/.env
fi

chainId=$($scriptPath/get-local-blockchain-env.sh CHAIN_ID)
genesisFile=$($scriptPath/get-local-blockchain-env.sh GENESIS_FILE)
sealerAccount=$($scriptPath/get-local-blockchain-env.sh SEALER_ACCOUNT)
sealerKeystore=$($scriptPath/get-local-blockchain-env.sh SEALER_KEYSTORE)
if [ -z "${genesisFile}" ]; then

  # TODO: All of the cases where we have a genesis file but we aren't a sealer
  newAccountOutput=$($geth account new --password "$localBlockchainPath/$sealerPassword" --datadir $localBlockchainPath)
  sealerAccount=$(echo $newAccountOutput | awk '{ print $11 }')
  sealerKeystore=$(realpath --relative-to=$localBlockchainPath $(echo $newAccountOutput | awk '{ print $18 }'))

  echo -n "Enter a chain ID for the blockchain genesis: "
  read chainId
  genesisFile=genesis.json
  node $scriptPath/make-genesis.js $chainId $sealerAccount > $localBlockchainPath/$genesisFile

  echo "CHAIN_ID=$chainId" >> $localBlockchainPath/.env
  echo "SEALER_ACCOUNT=$sealerAccount" >> $localBlockchainPath/.env
  echo "SEALER_KEYSTORE=$sealerKeystore" >> $localBlockchainPath/.env
  echo "GENESIS_FILE=$genesisFile" >> $localBlockchainPath/.env

fi

docker compose -f $localBlockchainPath/docker-compose.yml up
