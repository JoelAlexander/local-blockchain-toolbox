#!/bin/bash
scriptPath=$(dirname $(realpath $0))
mode=$1

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

if [ "$mode" = 'create' ]
then
  $scriptPath/setup-domain.sh $environmentFile
  $scriptPath/create-bootnode.sh $environmentFile
  $scriptPath/create-poa-blockchain.sh $environmentFile

  domain=$(jq -r '.domain' $environmentFile)
  echo "Writing nginx config for $domain"
  cat $scriptPath/nginx.conf.template | sed -e "s/{{DOMAIN}}/$domain/" > $scriptPath/nginx.conf

elif [ "$mode" = 'join' ]
then
  $scriptPath/create-bootnode.sh $environmentFile
  echo "Writing nginx config, no ssl"
  cat $scriptPath/nginx.conf.nossl.template | sed -e "s/{{DOMAIN}}/$domain/" > $scriptPath/nginx.conf
else
  echo "Must setup with option 'create' or 'join'" && exit 1
fi

$scriptPath/start-blockchain.sh $environmentFile
