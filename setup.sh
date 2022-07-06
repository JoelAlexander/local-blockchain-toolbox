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
  lsb-release\
  certbot\
  docker-ce\
  docker-ce-cli\
  containerd.io\
  docker-compose-plugin\

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
sudo groupadd -f docker
# TODO: test again
sudo usermod -aG docker $USER
newgrp docker

source setup2.sh
