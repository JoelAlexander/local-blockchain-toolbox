#!/bin/bash
scriptPath=$(dirname $(realpath $0))

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
    '.hyphenPath |= $hyphenPath'\
    $environmentFile | sponge $environmentFile
fi

$scriptPath/setup-domain.sh $environmentFile
$scriptPath/setup-bootnode.sh $environmentFile
$scriptPath/setup-gethnode.sh
$scriptPath/create-poa-blockchain.sh $environmentFile
$scriptPath/start-blockchain.sh $environmentFile
