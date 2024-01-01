#!/bin/bash
scriptPath=$(dirname $(realpath $0))
chainName=$1
domain=$2

# TODO: https? port 443?
sudo tailscale up --login-server https://$domain:443 --operator=$USER

$scriptPath/create-bootnode.sh $chainName
