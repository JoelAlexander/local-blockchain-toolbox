#!/bin/bash
docker compose stop
docker compose -f docker-compose.yml -f rpc.yml -f sealer.yml -f ssl.yml -f headscale.yml rm -v
rm -rf .env network.json package-lock.json creator.json environment.json bootnode.key password.txt genesis.json keystore http.conf headscale
cd ~
