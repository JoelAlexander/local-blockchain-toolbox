#!/bin/bash
scriptPath=$(dirname $(realpath $0))
environmentFile=$($scriptPath/get-environment-file.sh)
$scriptPath/stop-blockchain.sh $environmentFile stop
$scriptPath/stop-blockchain.sh $environmentFile remove
rm -rf .env network.json package-lock.json creator.json environment.json bootnode.key password.txt genesis.json keystore http.conf headscale
