#!/bin/bash
scriptPath=$(dirname $(realpath $0))
chainName=$1
domain=$2

if [ -z $chainName ] || [ -z $domain ]
then
  echo "Must provide both chain name and domain" && exit 1
fi

chainDir="$scriptPath/chains/$chainName"
genesisFile="$chainDir/genesis.json"
chainId=$(jq -r '.config.chainId' $genesisFile)
if [ "$chainId" == 'null' ]
then
  echo "ChainID not able to be read from genesis file $genesisFile" && exit 1
fi

chainConfig="$chainDir/config.json"
creatorPrivateKey=$(jq -r '.creator.privateKey' $chainConfig)

# TODO: Relax this requirement
if [ -z $creatorPrivateKey ]
then
  echo "Must have creator account" && exit 1
fi

jq --arg blockchainUrl "https://$domain"\
  --argjson chainId "$chainId"\
  --arg chainName "$chainName"\
  --arg creatorPrivateKey "$creatorPrivateKey"\
  '.networks."\($chainName)" |= { "chainId": $chainId, "url": $blockchainUrl, "accounts": [ $creatorPrivateKey ] } | .defaultNetwork |= $chainName'\
  $scriptPath/hardhat.config.json | sponge $scriptPath/hardhat.config.json
