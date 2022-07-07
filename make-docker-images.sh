#!/bin/bash

gethName=$(./install-geth.sh)

# Create the images we'll need and start them
docker build -f bootnode/Dockerfile -t bootnode:latest\
  --build-arg GETH_BIN="$gethName"\
  .

docker build -f gethnode/Dockerfile -t gethnode:latest\
  --build-arg GETH_BIN="$gethName"\
  .
