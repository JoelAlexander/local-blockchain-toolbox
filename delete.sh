#!/bin/bash

cd $(dirname $(realpath $0))
docker compose stop
docker compose rm -v
rm -rf .env creator.json environment.json bootnode.key password.txt genesis.json keystore nginx.conf
cd ~
