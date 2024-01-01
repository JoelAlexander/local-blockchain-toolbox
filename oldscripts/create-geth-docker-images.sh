#!/bin/bash
scriptPath=$(dirname $(realpath $0))
gethPath=$($scriptPath/install-geth.sh)

if [ -z $"$(docker image ls gethnode | awk '/^gethnode/ { print }')" ]
then
  docker build -f gethnode/Dockerfile -t gethnode:latest --build-arg GETH_BIN=host/geth-alltools-linux-arm64-1.10.26-e5eb32ac .
fi
