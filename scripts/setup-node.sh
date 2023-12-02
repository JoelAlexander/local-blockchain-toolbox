#!/bin/bash

# Install NVM (Node Version Manager)
echo "Installing NVM (Node Version Manager)..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Source NVM script to use it in the current session
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" 
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" 

# Install Node.js version 16 using NVM
echo "Installing Node.js version 16..."
nvm install 16
nvm use 16

# Check Node.js and NPM versions
echo "Node.js and NPM versions:"
node -v
npm -v

# Configuring Docker (Assuming Docker is already installed)
echo "Configuring Docker..."
# Include Docker configuration commands here

# Clone the Git repository
echo "Cloning the local-blockchain-toolbox repository..."
git clone https://github.com/JoelAlexander/local-blockchain-toolbox
cd local-blockchain-toolbox

# Update and install project dependencies
echo "Updating and installing project dependencies..."
npm update
npm install

# Run the status.sh script
echo "Running the status.sh script..."
./scripts/install-geth.sh
./scripts/status.sh
