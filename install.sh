#!/bin/bash
scriptPath=$(dirname $(realpath $0))
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
 "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
 $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y \
  resolvconf\
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
  git\
  make\
  gcc\
  g++\
  jq\
  moreutils

# Install tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# TODO: Check if nvm / node is already installed
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh > nvm.sh && chmod +x nvm.sh && ./nvm.sh && rm nvm.sh

# TODO: The following command could be extracted and used from the nvm install output
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

$scriptPath/install-geth.sh

nvm install 16 && nvm use 16

sudo systemctl enable NetworkManager.service
sudo systemctl start NetworkManager.service

sudo groupadd -f docker
sudo usermod -aG docker $USER
echo "Must log out and back in to use docker."
