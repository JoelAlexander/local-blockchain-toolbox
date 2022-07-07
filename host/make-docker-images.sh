#!/bin/bash
scriptPath=$(dirname $(realpath $0))
localBlockchainPath=$($scriptPath/get-blockchain-directory.sh)

gethName=$($scriptPath/install-geth.sh)

cp $scriptPath/docker-compose.yml $localBlockchainPath
cp $scriptPath/entrypoint.sh $localBlockchainPath

# Create the images we'll need and start them
docker build -f $scriptPath/bootnode/Dockerfile -t bootnode:latest\
  --build-arg GETH_BIN=$gethName\
  $localBlockchainPath

docker build -f $scriptPath/gethnode/Dockerfile -t gethnode:latest\
  --build-arg GETH_BIN=$gethName\
  $localBlockchainPath
