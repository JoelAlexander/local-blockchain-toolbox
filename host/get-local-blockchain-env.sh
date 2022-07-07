#!/bin/bash
scriptPath=$(dirname $(realpath $0))
localBlockchainPath=$($scriptPath/get-blockchain-directory.sh)

if [ -z $1 ]
then
  echo "Key name expected" && exit 1
fi

awkScript="/^$1=/ { print \$2 }"
echo $([ -f $localBlockchainPath/.env ] && awk -F'=' $"$awkScript" $localBlockchainPath/.env | head -1)
