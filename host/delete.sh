#!/bin/bash

scriptPath=$(dirname $(realpath $0))
cd $($scriptPath/get-blockchain-directory.sh)

cd ~/.local-blockchain
docker compose stop
docker compose rm -v
rm -rf .env scripts hardhat.config.json contracts cache artifacts hardhat.config.js package.json package-lock.json creator.json environment.json bootnode.key password.txt genesis.json keystore nginx.conf entrypoint.sh docker-compose.yml
cd ~
