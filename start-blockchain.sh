#!/bin/bash
scriptPath=$(dirname $(realpath $0))
environmentFile=$1

# Create the .env file needed by dockerfile
touch $scriptPath/.env
echo "CERT_FULLCHAIN=$(jq '.fullchain' $environmentFile)" > $scriptPath/.env
echo "CERT_PRIVKEY=$(jq '.privkey' $environmentFile)" >> $scriptPath/.env
echo "HYPHEN_PATH=$(jq '.hyphenPath' $environmentFile)" >> $scriptPath/.env
echo "BOOTNODE_KEY=$(jq '.bootnodeKey' $environmentFile)" >> $scriptPath/.env
echo "BOOTNODE_ENODE=$(jq '.bootnodeEnode' $environmentFile)" >> $scriptPath/.env
echo "CHAIN_ID=$(jq '.chainId' $environmentFile)" >> $scriptPath/.env
echo "SEALER_ACCOUNT=$(jq '.sealerAccount' $environmentFile)" >> $scriptPath/.env
echo "SEALER_KEYSTORE=$(jq '.sealerKeystore' $environmentFile)" >> $scriptPath/.env
echo "SEALER_PASSWORD=$(jq '.sealerPassword' $environmentFile)" >> $scriptPath/.env
echo "GENESIS_FILE=$(jq '.genesisFile' $environmentFile)" >> $scriptPath/.env
echo "DOMAIN=$(jq '.domain' $environmentFile)" >> $scriptPath/.env

docker compose -f $scriptPath/docker-compose.yml up -d

blockchainUrl=$(jq -r '.blockchainUrl' $environmentFile)
status=$(curl $blockchainUrl)
while [ ! -z $status ]
do
  echo "Waiting for blockchain to come online."
  sleep 2
  status=$(curl $blockchainUrl)
done

echo "Blockchain online."
