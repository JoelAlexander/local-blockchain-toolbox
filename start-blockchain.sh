#!/bin/bash
scriptPath=$(dirname $(realpath $0))
gethPath=$($scriptPath/install-geth.sh)
bootnode="$gethPath/bootnode"
chainName=$1
domain=$2

dockerPath="$scriptPath/docker"
chainDir="$scriptPath/chains/$chainName"
if [ ! -d $chainDir ]
then
  echo "Chain $chainName does not exist" && exit 1
fi

# Create the .env file needed by dockerfile
envFile=$dockerPath/.env
touch $envFile && echo -n "" > $envFile
echo "HOST_DIR=$scriptPath/host" >> $envFile

composeFileArgs="-f $dockerPath/docker-compose.yml -f $dockerPath/rpc.yml"

certs="/etc/letsencrypt/live/$domain"
fullchain="$certs/fullchain.pem"
privkey="$certs/privkey.pem"

if [ ! -z "$domain" ] && sudo test -f "$fullchain" && sudo test -f "$privkey"
then
  composeFileArgs="$composeFileArgs -f $dockerPath/ssl.yml"
  echo "DOMAIN=$domain" >> $envFile
  echo "CERT_FULLCHAIN=$fullchain" >> $envFile
  echo "CERT_PRIVKEY=$privkey" >> $envFile
  echo "Writing nginx config for $domain"
  cat $scriptPath/templates/http.rpc.conf.template | sed -e "s/{{DOMAIN}}/$domain/" > $scriptPath/host/http.conf
else
  echo "Writing nginx config, no ssl"
  cat $scriptPath/templates/http.conf.nossl.template > $scriptPath/host/http.conf
fi

headscaleConfig="$scriptPath/host/headscale/config"
if [ -d "$headscaleConfig" ]
then
  composeFileArgs="$composeFileArgs -f $dockerPath/headscale.yml"
  echo "HEADSCALE_PATH=$headscaleConfig" >> $envFile
fi

genesisFileName=genesis.json
genesisFile="$chainDir/$genesisFileName"
chainId=$(jq -r '.config.chainId' $genesisFile)
bootnodeKey=$(cat $chainDir/bootnode.key)
bootnodeEnode=$($bootnode -nodekeyhex $bootnodeKey -writeaddress)
echo "CHAIN_DIR=$chainDir" >> $envFile
echo "CHAIN_ID=$chainId" >> $envFile
echo "BOOTNODE_ENODE=$bootnodeEnode" >> $envFile

sealerAccount=$(jq -r '.extraData|split("x")[1][64:104]' $chainDir/genesis.json)
sealerAccountHex=$sealerAccount
sealerKeystore=$(find $chainDir -type f -iname "*$sealerAccount" | head -n 1)
sealerPassword=$chainDir/password.txt
if [ -f "$sealerKeystore" ] && [ -f "$sealerPassword" ]
then
  composeFileArgs="$composeFileArgs -f $dockerPath/sealer.yml"
  echo "SEALER_ACCOUNT=$sealerAccountHex" >> $envFile

  sealerKeystoreFileName=$(basename $sealerKeystore)
  echo "SEALER_KEYSTORE=$sealerKeystoreFileName" >> $envFile
fi

applicationPath=~/hyphen
if [ -d "$applicationPath" ]
then
  composeFileArgs="$composeFileArgs -f $dockerPath/application.yml"
  echo "APPLICATION_PATH=$applicationPath" >> $envFile
fi

echo "$composeFileArgs"
docker compose $composeFileArgs up
