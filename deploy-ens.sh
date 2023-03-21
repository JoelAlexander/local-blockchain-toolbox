#!/bin/bash
scriptPath=$(dirname $(realpath $0))
gethPath=$($scriptPath/install-geth.sh)
chainName=$1

if [ -z $chainName ]
then
  echo "Must enter a chain name" && exit 1
fi

chainDir="$scriptPath/chains/$chainName"
if [ ! -d $chainDir ]
then
  echo "Chain $chainName does not exist" && exit 1
fi

# Could provide a better verification here
defaultNetwork=$(jq -r '.defaultNetwork' $scriptPath/hardhat.config.json)
if [ $chainName != $defaultNetwork ]
then
  echo "Chain is not currently in use, you may need to ./use-chain.sh $chainName" && exit 1
fi

configFile="$chainDir/config.json"
ensAddress=$(jq -r '.ensAddress' $configFile)
if [ "$ensAddress" != 'null' ]
then
  echo "Chain already configured with ENS: $ensAddress" && exit 1
fi

ensAddress=$(npx hardhat deployEnsRegistry)
if [ ! -z $ensAddress ]
then
  jq --arg ensAddress "$ensAddress"\
    '.ensAddress |= $ensAddress'\
    $configFile | sponge $configFile
  echo "ENS registry deployed to: $ensAddress, use ./use-chain.sh $chainName {domain} to load ens address into hardhat"
fi
