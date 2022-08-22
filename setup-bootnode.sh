#!/bin/bash
scriptPath=$(dirname $(realpath $0))
gethName=$($scriptPath/install-geth.sh)
bootnode="$scriptPath/$gethName/bootnode"
environmentFile=$1

# Reads from the .env file, reusing values that it can, and creating what's needed.
bootnodeKey=$(jq -r '.bootnodeKey' $environmentFile)
bootnodeEnode=$(jq -r '.bootnodeEnode' $environmentFile)
if [ "$bootnodeKey" = 'null' ] && [ "$bootnodeEnode" = 'null' ]
then
  echo "Creating new bootnode."
  bootnodeKey=bootnode.key
  bootnodeEnode=$($bootnode -genkey $scriptPath/bootnode.key -writeaddress)
  jq --arg bootnodeKey $bootnodeKey\
    --arg bootnodeEnode $bootnodeEnode\
    '.bootnodeKey |= $bootnodeKey | .bootnodeEnode |= $bootnodeEnode'\
    $environmentFile | sponge $environmentFile
elif [ "$bootnodeKey" = 'null' ] || [ "$bootnodeEnode" = 'null' ]
then
  echo "Invalid environment file, both BOOTNODE_KEY and BOOTNODE_ENODE should be set or unset"
else
  echo "Using bootnode: $bootnodeEnode with key $bootnodeKey"
fi

if [ -z $"$(docker image ls bootnode | awk '/^bootnode/ { print }')" ]
then
  docker build -f $scriptPath/bootnode/Dockerfile -t bootnode:latest\
    --build-arg GETH_BIN=$gethName\
    $scriptPath
fi
