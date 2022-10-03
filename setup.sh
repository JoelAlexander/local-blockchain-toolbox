#!/bin/bash
scriptPath=$(dirname $(realpath $0))
mode=$1
domain=$2

$scriptPath/create-geth-docker-images.sh

environmentFile=$($scriptPath/get-environment-file.sh)

$scriptPath/setup-network.sh

source $NVM_DIR/nvm.sh
nvm use 16
echo "Installing npm dependencies"
npm install
echo "Compiling contracts"
npm run contracts

# TODO: Remove references to hyphen, inverting control
hyphenPath=$(jq -r '.hyphenPath' $environmentFile)
if [ "$hyphenPath" = 'null' ]
then
  git -C ~ clone https://github.com/JoelAlexander/hyphen
  hyphenPath=$(readlink -f ~/hyphen)
  jq --arg hyphenPath $hyphenPath\
    '.applicationPath |= $hyphenPath'\
    $environmentFile | sponge $environmentFile
fi

if [ -z $domain ]
then
  echo "Domain must be provided" && exit 1
fi

if [ "$mode" = 'create' ]
then
  $scriptPath/setup-domain.sh $environmentFile $domain
  $scriptPath/setup-headscale.sh $environmentFile
  $scriptPath/create-bootnode.sh $environmentFile
  $scriptPath/create-poa-blockchain.sh $environmentFile
elif [ "$mode" = 'join' ]
then
  $scriptPath/create-bootnode.sh $environmentFile
  $scriptPath/join-network.sh $domain
else
  echo "Must setup with option 'create' or 'join'" && exit 1
fi

$scriptPath/start-blockchain.sh $environmentFile
