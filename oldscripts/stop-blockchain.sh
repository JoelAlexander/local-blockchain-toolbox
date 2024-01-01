#!/bin/bash
scriptPath=$(dirname $(realpath $0))
gethPath=$($scriptPath/install-geth.sh)
bootnode="$gethPath/bootnode"
mode=$1
chainName=$2
domain=$3

dockerPath="$scriptPath/docker"
chainDir="$scriptPath/chains/$chainName"
if [ ! -d $chainDir ]
then
  echo "Chain $chainName does not exist" && exit 1
fi

composeFileArgs="-f $dockerPath/docker-compose.yml -f $dockerPath/rpc.yml"

certs=$(sudo certbot certificates -d "$domain")
fullchain=$(echo "$certs" | awk -F ':' '$1 ~ /Certificate Path/ { print $2; exit }')
privkey=$(echo "$certs" | awk -F ':' '$1 ~ /Private Key Path/ { print $2; exit }')
if sudo test -f "$fullchain" && sudo test -f "$privkey"
then
  composeFileArgs="$composeFileArgs -f $dockerPath/ssl.yml"
fi

sealerAccount=$(jq -r '.extraData|split("x")[1][64:104]' $chainDir/genesis.json)
sealerKeystore=$(sudo find $chainDir -type f -iname "*$sealerAccount" | head -n 1)
sealerPassword=$chainDir/password.txt
if [ -f "$sealerKeystore" ] && [ -f "$sealerPassword" ]
then
  composeFileArgs="$composeFileArgs -f $dockerPath/sealer.yml"
fi

applicationPath=~/hyphen
if [ -d $applicationPath ]
then
  composeFileArgs="$composeFileArgs -f $dockerPath/application.yml"
fi

headscaleConfig="$scriptPath/headscale/config"
if [ -d $headscaleConfig ]
then
  composeFileArgs="$composeFileArgs -f $dockerPath/headscale.yml"
fi

# This might be split into a script which creates the compose args and two calling scripts
# For stop and remove.  That eliminates the 
if [ "$mode" = 'stop' ]
then
  docker compose $composeFileArgs stop
elif [ "$mode" = 'remove' ]
then
  docker compose $composeFileArgs rm -v
fi
