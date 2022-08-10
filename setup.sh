#!/bin/bash
scriptPath=$(dirname $(realpath $0))
gethName=$($scriptPath/install-geth.sh)
geth="$scriptPath/$gethName/geth"
bootnode="$scriptPath/$gethName/bootnode"

source $NVM_DIR/nvm.sh

echo "Installing npm dependencies"
npm install

# Lazily create empty environment file if it doesn't exist already
environmentFile="$scriptPath/environment.json"
if [ ! -f $environmentFile ]
then
  echo '{}' > $environmentFile
fi

# Detect wireless interface
interfaces=$(ifconfig -a | awk '/^[a-zA-Z0-9]/ { print $1 }' | sed -e 's\:\\')
for i in ${interfaces[@]}
do
  if [[ -d "/sys/class/net/${i}/wireless" ]]; then
    wirelessInterface=${i}
    break
  fi
done

if [ -z $wirelessInterface ]; then
  echo "No wireless interface was found"
  exit 1
fi

wirelessStatus=$(nmcli dev status | awk -v devRegex="^$wirelessInterface" 'match($0, devRegex) { print $3 }')
if [ $wirelessStatus = "disconnected" ]
then
  # TODO: Scan for and suggest whileifi networks
  while [ $wirelessStatus = "disconnected" ]
  do
    echo -n "Enter wireless network name (SSID): "
    read ssid
    echo -n "Enter wireless network password: "
    read wirelessPassword
    sudo nmcli dev wifi connect $ssid password $wirelessPassword > /dev/null
    wirelessStatus=$(nmcli dev status | awk -v devRegex="^$wirelessInterface" 'match($0, devRegex) { print $3 }')
  done
fi

macAddress=$(nmcli dev show $wirelessInterface | awk '/GENERAL.HWADDR/ { print $2 }')
gateway=$(nmcli dev show $wirelessInterface | awk '/IP4.GATEWAY/ { print $2 }')
ipAddress=$(nmcli dev show $wirelessInterface | awk '/IP4.ADDRESS/ { print $2 }' | sed -e 's/\/.*//')

echo "Before proceding: "
echo "Access the admin panel on your router: http://$gateway"
echo "Give $macAddress a static IP of $ipAddress"

domain=$(jq -r '.domain' $environmentFile)
if [ "$domain" == 'null' ]
then
  echo -n "Enter your domain: "
  read domain
  sudo certbot certonly --manual --preferred-challenges=dns -d "$domain" -d "blockchain.$domain" --register-unsafely-without-email
  jq --arg domain $domain '.domain |= $domain' $environmentFile | sponge $environmentFile
fi

# TODO: Detect certificates better than just guessing
certs="/etc/letsencrypt/live/$domain"
fullchain=$(jq -r '.fullchain' $environmentFile)
privkey=$(jq -r '.privkey' $environmentFile)
if [ "$fullchain" = 'null' ] && [ "$privkey" = 'null' ]
then
  if sudo test ! -f "$certs/fullchain.pem" && sudo test ! -f "$certs/privkey.pem"
  then
    echo "SSL certificates for $domain not found"
  fi

  fullchain=$(sudo readlink -f "$certs/fullchain.pem")
  privkey=$(sudo readlink -f "$certs/privkey.pem")
  sudo chown $USER $fullchain $privkey
  jq --arg fullchain $fullchain\
    --arg privkey $privkey\
    '.fullchain |= $fullchain | .privkey |= $privkey'\
    $environmentFile | sponge $environmentFile
fi

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
  echo "Invalid .env file, both BOOTNODE_KEY and BOOTNODE_ENODE should be set or unset"
fi

sealerPassword=$(jq -r '.sealerPassword' $environmentFile)
if [ "$sealerPassword" = 'null' ]
then
  # TODO: The key is unlocked with no password, so is only as secure as the host password
  echo -n "Enter a password for the new sealing account: "
  read password
  sealerPassword=password.txt
  echo $password > $scriptPath/$sealerPassword
  jq --arg sealerPassword $sealerPassword\
    '.sealerPassword |= $sealerPassword'\
    $environmentFile | sponge $environmentFile
fi

hyphenPath=$(jq -r '.hyphenPath' $environmentFile)
if [ "$hyphenPath" = 'null' ]
then
  git -C ~ clone https://github.com/JoelAlexander/hyphen
  hyphenPath=$(readlink -f ~/hyphen)
  jq --arg hyphenPath $hyphenPath\
    '.hyphenPath |= $hyphenPath'\
    $environmentFile | sponge $environmentFile
fi

chainId=$(jq -r '.chainId' $environmentFile)
genesisFile=$(jq -r '.genesisFile' $environmentFile)
sealerAccount=$(jq -r '.sealerAccount' $environmentFile)
sealerKeystore=$(jq -r '.sealerKeystore' $environmentFile)
creatorFile=$(jq -r '.creatorFile' $environmentFile)
if [ "$genesisFile" = 'null' ]
then

  # TODO: All of the cases where we have a genesis file but we aren't a sealer
  newAccountOutput=$($geth account new --password "$scriptPath/$sealerPassword" --datadir $scriptPath)
  sealerAccount=$(echo $newAccountOutput | awk '{ print $11 }')
  sealerKeystore=$(realpath --relative-to=$scriptPath $(echo $newAccountOutput | awk '{ print $18 }'))

  echo -n "Enter a chain ID for the blockchain genesis: "
  read chainId
  genesisFile=genesis.json
  creatorFile=creator.json

  npx hardhat makeGenesis --chain-id $chainId --sealer-address $sealerAccount --genesis-file $genesisFile --creator-file $creatorFile

  jq --argjson chainId $chainId\
    --arg sealerAccount $sealerAccount\
    --arg sealerKeystore $sealerKeystore\
    --arg genesisFile $genesisFile\
    --arg creatorFile $creatorFile\
    '.chainId |= $chainId | .sealerAccount |= $sealerAccount | .sealerKeystore |= $sealerKeystore | .genesisFile |= $genesisFile | .creatorFile |= $creatorFile'\
    $environmentFile | sponge $environmentFile
fi

cat $scriptPath/nginx.conf.template | sed -e "s/{{DOMAIN}}/$domain/" > $scriptPath/nginx.conf

# Create the .env file needed by dockerfile
touch $scriptPath/.env
echo "CERT_FULLCHAIN=$(jq '.fullchain' $environmentFile)" > $scriptPath/.env
echo "CERT_PRIVKEY=$(jq '.privkey' $environmentFile)" >> $scriptPath/.env
echo "HYPHEN_PATH=$(jq '.hyphenPath' $environmentFile)" >> $scriptPath/.env
echo "BOOTNODE_KEY=$(jq '.bootnodeKey' $environmentFile)" >> $scriptPath/.env
echo "BOOTNODE_ENODE=$(jq '.bootnodeEnode' $environmentFile)" >> $scriptPath/.env
echo "CHAIN_ID=$(jq '.chainId' $environmentFile)" >> $scriptPath/.env
echo "SEALER_ACCOUNT=$(jq '.sealerAccount' $environmentFile)" >> $scriptPath/.env
echo "SEALER_KEYSTORE=$(jq '.sealerKeystore' $environmentFile)" >> $scriptPath/.env
echo "SEALER_PASSWORD=$(jq '.sealerPassword' $environmentFile)" >> $scriptPath/.env
echo "GENESIS_FILE=$(jq '.genesisFile' $environmentFile)" >> $scriptPath/.env
echo "DOMAIN=$(jq '.domain' $environmentFile)" >> $scriptPath/.env

if [ -z $"$(docker image ls bootnode | awk '/^bootnode/ { print }')" ]
then
  docker build -f $scriptPath/bootnode/Dockerfile -t bootnode:latest\
    --build-arg GETH_BIN=$gethName\
    $scriptPath
fi

if [ -z $"$(docker image ls gethnode | awk '/^gethnode/ { print }')" ]
then
  docker build -f $scriptPath/gethnode/Dockerfile -t gethnode:latest\
    --build-arg GETH_BIN=$gethName\
    $scriptPath
fi

docker compose -f $scriptPath/docker-compose.yml up -d

blockchainUrl="https://blockchain.$domain/"
status=$(curl $blockchainUrl)
while [ ! -z $status ]
do
  echo "Waiting for blockchain to come online."
  sleep 2
  status=$(curl $blockchainUrl)
done

jq --arg blockchainUrl $blockchainUrl '.blockchainUrl |= $blockchainUrl'\
  $environmentFile | sponge $environmentFile

creatorPrivateKey=$(jq -r '.privateKey' $scriptPath/$creatorFile)
jq --null-input\
  --arg creatorPrivateKey $creatorPrivateKey\
  --argjson chainId $chainId\
  --arg blockchainUrl $blockchainUrl\
  '{ "chainId": $chainId, "url": $blockchainUrl, "accounts": [ $creatorPrivateKey ]}' | sponge $scriptPath/network.json

echo "Blockchain online."
echo "Compiling contracts"
npm run contracts
# echo "Deploying genesis contracts"
# npm run deployGenesis
#
# npm run configureModule ~/hyphen
#
# cd ~/hyphen
# npm install
# npm run contracts
# npm run build
# npm run deployModule
