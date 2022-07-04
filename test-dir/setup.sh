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

source setup2.sh

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
