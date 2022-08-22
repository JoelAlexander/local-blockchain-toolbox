#!/bin/bash
source $NVM_DIR/nvm.sh
nvm use 16
echo "Installing npm dependencies"
npm install

echo "Deploying genesis contracts"
npx hardhat deployGenesis
