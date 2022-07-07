#!/bin/bash

docker compose down
docker compose rm -v
docker container prune
docker volume prune
rm -rf .env bootnode.key password.txt genesis.json keystore
