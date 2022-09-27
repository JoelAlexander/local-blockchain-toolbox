#!/bin/bash
scriptPath=$(dirname $(realpath $0))
gethName=$($scriptPath/install-geth.sh)

if [ -z $"$(docker image ls gethnode | awk '/^gethnode/ { print }')" ]
then
  docker build -f $scriptPath/gethnode/Dockerfile -t gethnode:latest\
    --build-arg GETH_BIN=$gethName\
    $scriptPath
fi
