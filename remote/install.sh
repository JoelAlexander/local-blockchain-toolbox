#!/bin/bash
scriptPath=$(dirname $(realpath $0))

if [ -z $1 ]
then
  echo "hostname or ip required" && exit 1
fi

$scriptPath/build.sh &&\
scp local-blockchain-node.tar.gz ubuntu@$1:~/. &&\
ssh ubuntu@$1 'tar -xvzf local-blockchain-node.tar.gz'
