#!/bin/bash
docker compose stop
docker compose rm -v
rm -rf .env network.json package-lock.json creator.json environment.json bootnode.key password.txt genesis.json keystore http.conf
cd ~
