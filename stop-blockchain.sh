#!/bin/bash
scriptPath=$(dirname $(realpath $0))
environmentFile=$1
mode=$2

composeFileArgs="-f $scriptPath/docker-compose.yml"

domain=$(jq -r '.domain' $environmentFile)
certFullchain=$(jq -r '.fullchain' $environmentFile)
certPrivkey=$(jq -r '.privkey' $environmentFile)
if [ "$domain" != 'null' ] &&\
   [ "$certFullchain" != 'null' ] &&\
   [ "$certPrivkey" != 'null' ]
then
  composeFileArgs="$composeFileArgs -f $scriptPath/ssl.yml"
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
fi

applicationPath=$(jq -r '.applicationPath' $environmentFile)
if [ "$applicationPath" != 'null' ]
then
  composeFileArgs="$composeFileArgs -f $scriptPath/application.yml"
fi

headscaleConfig=$(jq -r '.headscaleConfig' $environmentFile)
if [ "$headscaleConfig" != 'null' ]
then
  composeFileArgs="$composeFileArgs -f $scriptPath/headscale.yml"
fi

if [ "$mode" = 'stop' ]
then
  docker compose $composeFileArgs stop
elif [ "$mode" = 'remove' ]
then
  docker compose $composeFileArgs rm -v
fi
