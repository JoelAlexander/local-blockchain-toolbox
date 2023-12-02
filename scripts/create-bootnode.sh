#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"
gethPath=$($SCRIPT_DIR/install-geth.sh)
bootnode="$gethPath/bootnode"
chainName=$1

bootnodeKey="$SCRIPT_DIR/chains/$chainName/bootnode.key"
if [ ! -f "$bootnodeKey" ]
then
  $bootnode -genkey $bootnodeKey
fi
