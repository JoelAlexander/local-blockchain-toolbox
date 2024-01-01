#!/bin/bash
scriptPath=$(dirname $(realpath $0))
modulePath=$1

source $NVM_DIR/nvm.sh
nvm use 16
echo "Installing npm dependencies"
npm install

npx hardhat configureModule --module-path $modulePath

# Inside the module directory
cd $modulePath
npm install
npm run contracts
npm run build
cd $scriptPath

npx hardhat deployModule --module-path $modulePath
