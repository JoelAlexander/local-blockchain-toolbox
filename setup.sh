#!/bin/bash

# TODO: Make this script less chatty, and only touching things if it needs to.

# TODO: Check if connected to ethernet...rare but obvious failure mode?
sudo apt update
sudo apt install -y \
  net-tools \
  wireless-tools \
  network-manager \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

# TODO: Check if nvm / node is already installed
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh > nvm.sh && chmod +x nvm.sh && ./nvm.sh && rm nvm.sh

# TODO: The following command could be extracted and used from the nvm install output
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# TODO: Check if node / ethers is already installed
nvm install 16 && nvm use 16
npm install ethers

sudo systemctl start NetworkManager.service
sudo systemctl enable NetworkManager.service

# Install and setup Docker
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
 "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
 $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo groupadd -f docker
# sudo usermod -aG docker $USER
# newgrp docker

# TODO: Assumes linux
machine=$(uname -m)
if [ $machine == "x86_64" ]; then
  variant="amd64"
elif [ $machine == "aarch64" ]; then
  variant="arm64"
else
  echo "$machine is not a supported platform."
  exit
fi

# TODO: Probably could clean up this geth install to be more respectful
gethName="geth-alltools-linux-${variant}-1.10.19-23bee162"
gethPackage="$gethName.tar.gz"
gethDownload="https://gethstore.blob.core.windows.net/builds/$gethPackage"
if ! [ -x "$(command -v geth)" ]; then
  echo "Downloading geth from $gethDownload" && curl $gethDownload --output $gethPackage && tar -xzf $gethPackage || exit
  gethPath=$(readlink -f $gethName)
  echo 'export PATH=$PATH:'$gethPath >> ~/.profile
  source ~/.profile
else
  # TODO: Which geth?
  echo "Using geth at $gethPath"
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
  exit
else
  echo "Using wireless interface $wirelessInterface"
fi

wirelessStatus=$(nmcli dev status | awk -v devRegex="^$wirelessInterface" 'match($0, devRegex) { print $3 }')
if [ "$wirelessStatus" == "disconnected" ]; then
  # TODO: Scan for the best wifi network.
  read -p "Enter wireless network SSID: " ssid
  read -p "Enter wireless network password: " wirelessPassword
  nmcli dev wifi connect $ssid password $wirelessPassword
elif [ "$wirelessStatus" == "connected" ]; then
  echo "Already connected on $wirelessInterface"
fi

# Build a new local network around a bootnode
bootnodeEnode=$(bootnode -genkey bootnode.key -writeaddress)

touch password.txt
newAccountOutput=$(geth account new --password password.txt --datadir .)
sealingAccountAddress=$(echo $newAccountOutput | awk '{ print $11 }')
sealingAccountKeystore=$(realpath --relative-to=. $(echo $newAccountOutput | awk '{ print $18 }'))

echo -n "Enter a chain ID for the blockchain genesis: "
read chainId
node make-genesis.js $chainId $sealingAccountAddress > genesis.json

# Create the images we'll need and start them
docker build -f bootnode/Dockerfile -t bootnode:latest\
  --build-arg GETH_BIN="$gethName"\
  --build-arg BOOTNODE_KEY=bootnode.key\
  .
docker build -f sealingnode/Dockerfile -t sealingnode:latest\
  --build-arg GETH_BIN="$gethName"\
  --build-arg ACCOUNT_KEYSTORE=$sealingAccountKeystore\
  --build-arg GENESIS_FILE=genesis.json\
  --build-arg CHAIN_ID=$chainId\
  .
docker build -f rpcnode/Dockerfile -t rpcnode:latest\
  --build-arg GETH_BIN="$gethName"\
  --build-arg GENESIS_FILE=genesis.json\
  --build-arg CHAIN_ID=$chainId\
  .

echo "" > .env
echo "BOOTNODE_ENODE=$bootnodeEnode" >> .env
echo "CHAIN_ID=$chainId" >> .env

docker-compose up

# docker build -f sealing-node/Dockerfile -t bootnode:latest --buildarg gethPath=$getPath

# node create-congregation-key.js

# TODO: Revise where hostname comes from...should be identified by the communityKey?
# if [ ! -f "hostname.txt" ]; then
#   openssl rand -hex 16 > "hostname.txt"
# fi

# hostname=$(cat "hostname.txt")
#
# macAddress=$(nmcli dev show $wirelessInterface | awk '/GENERAL.HWADDR/ { print $2 }')
# gateway=$(nmcli dev show $wirelessInterface | awk '/IP4.GATEWAY/ { print $2 }')
# ipAddress=$(nmcli dev show $wirelessInterface | awk '/IP4.ADDRESS/ { print $2 }' | sed -e 's/\/.*//')
#
# echo "Access the admin panel on your router: http://$gateway"
# echo "Give $macAddress a static IP of $ipAddress with a hostname of $hostname"

# Get certificates for domain that the blockchain will be served on
# apt install -y certbot
# certbot certonly
