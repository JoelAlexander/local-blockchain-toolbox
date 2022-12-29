#!/bin/bash
scriptPath=$(dirname $(realpath $0))
gethPath=$($scriptPath/install-geth.sh)
bootnode="$gethPath/bootnode"
chainName=$1

bootnodeKey="$scriptPath/chains/$chainName/bootnode.key"
if [ ! -f "$bootnodeKey" ]
then
  $bootnode -genkey $bootnodeKey
fi
