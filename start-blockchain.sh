#!/bin/bash
scriptPath=$(dirname $(realpath $0))
environmentFile=$1

# Create the .env file needed by dockerfile
touch $scriptPath/.env && echo -n "" > $scriptPath/.env

composeFileArgs="-f $scriptPath/docker-compose.yml"

domain=$(jq -r '.domain' $environmentFile)
certFullchain=$(jq -r '.fullchain' $environmentFile)
certPrivkey=$(jq -r '.privkey' $environmentFile)
if [ "$domain" != 'null' ] &&\
   [ "$certFullchain" != 'null' ] &&\
   [ "$certPrivkey" != 'null' ]
then
  composeFileArgs="$composeFileArgs -f $scriptPath/ssl.yml"
  echo "DOMAIN=$domain" >> $scriptPath/.env
  echo "CERT_FULLCHAIN=$certFullchain" >> $scriptPath/.env
  echo "CERT_PRIVKEY=$certPrivkey" >> $scriptPath/.env
fi

genesisFile="genesis.json"
chainId=$(jq -r '.config.chainId' $genesisFile)
bootnodeKey=$(jq -r '.bootnodeKey' $environmentFile)
bootnodeEnode=$(jq -r '.bootnodeEnode' $environmentFile)
if\
  [ -f $genesisFile ] &&\
  [ "$chainId" != 'null' ] &&\
  [ "$bootnodeKey" != 'null' ] &&\
  [ "$bootnodeEnode" != 'null' ]
then
  composeFileArgs="$composeFileArgs -f $scriptPath/rpc.yml"
  echo "GENESIS_FILE=$genesisFile" >> $scriptPath/.env
  echo "CHAIN_ID=$chainId" >> $scriptPath/.env
  echo "BOOTNODE_KEY=$bootnodeKey" >> $scriptPath/.env
  echo "BOOTNODE_ENODE=$bootnodeEnode" >> $scriptPath/.env
else
  echo "Genesis file and bootnode information required to start blockchain" && exit 1
fi

sealerAccount=$(jq -r '.sealerAccount' $environmentFile)
sealerKeystore=$(jq -r '.sealerKeystore' $environmentFile)
sealerPassword=$(jq -r '.sealerPassword' $environmentFile)
if\
  [ "$sealerAccount" != 'null' ] &&\
  [ "$sealerKeystore" != 'null' ] &&\
  [ "$sealerPassword" != 'null' ]
then
  composeFileArgs="$composeFileArgs -f $scriptPath/sealer.yml"
  echo "SEALER_ACCOUNT=$sealerAccount" >> $scriptPath/.env
  echo "SEALER_KEYSTORE=$sealerKeystore" >> $scriptPath/.env
  echo "SEALER_PASSWORD=$sealerPassword" >> $scriptPath/.env
else
  echo "No sealing account specified, skipping sealing node"
fi

applicationPath=$(jq -r '.applicationPath' $environmentFile)
if [ "$applicationPath" != 'null' ]
then
  composeFileArgs="$composeFileArgs -f $scriptPath/application.yml"
  echo "APPLICATION_PATH=$applicationPath" >> $scriptPath/.env
else
  echo "No application path specified, skipping nginx application volume"
fi

docker compose\
  $composeFileArgs\
  up -d

blockchainUrl=$(jq -r '.blockchainUrl' $environmentFile)
status=$(curl $blockchainUrl)
# TODO: This while loop doesn't quite work...e.g.when DNS is not set up correctly
while [ ! -z $status ]
do
  echo "Waiting for blockchain to come online."
  sleep 2
  status=$(curl $blockchainUrl)
done

echo "Blockchain online."
