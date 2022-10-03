#!/bin/bash
machineKey=$1

if [ -z $machineKey ]
then
  echo "Must specify machine key" && exit 1
fi

# TODO: Namespace name is fixed, maybe should be dynamic?
docker exec headscale headscale --namespace nodes nodes register --key $machineKey
