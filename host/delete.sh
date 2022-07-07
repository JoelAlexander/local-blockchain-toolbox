#!/bin/bash

scriptPath=$(dirname $(realpath $0))
cd $($scriptPath/get-blockchain-directory.sh)

docker compose down
docker compose rm -v
docker container prune
docker volume prune
docker network prune
rm -rf .env bootnode.key password.txt genesis.json keystore nginx.conf docker-comopse.yml entrypoint.sh
