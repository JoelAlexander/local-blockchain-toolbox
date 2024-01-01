#!/bin/bash
scriptPath=$(dirname $(realpath $0))
mode=$1
chainName=$2
domain=$3

$scriptPath/create-geth-docker-images.sh
$scriptPath/setup-network.sh

source $NVM_DIR/nvm.sh
nvm use 16
echo "Installing npm dependencies"
npm install
echo "Compiling contracts"
npm run contracts

if [ -z $domain ]
then
  echo "Domain must be provided" && exit 1
fi

if [ "$mode" = 'create' ]
then
  $scriptPath/setup-domain.sh $domain
  $scriptPath/setup-headscale.sh $domain
  $scriptPath/create-poa-blockchain.sh $chainName
elif [ "$mode" = 'join' ]
then
  $scriptPath/join-network.sh $chainName $domain
else
  echo "Must setup with option 'create' or 'join'" && exit 1
fi

$scriptPath/start-blockchain.sh $chainName $domain
