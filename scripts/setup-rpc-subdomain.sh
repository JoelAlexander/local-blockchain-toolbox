#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 <domain>"
}

# Check if a base domain is provided
if [ -z "$1" ]; then
    usage
    exit 1
fi

RPC_DOMAIN="$1"
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

# Call setup-domain.sh with the full domain name
if [ "localhost" != $RPC_DOMAIN ]; then
	${SCRIPT_DIR}/setup-domain.sh $RPC_DOMAIN -t
fi

# Update profile with RPC domain information
echo "Setup for rpc domain: $RPC_DOMAIN in profile $ACTIVE_PROFILE"
jq --arg rpcDomain "$RPC_DOMAIN" '.rpc.domain = $rpcDomain' "$ACTIVE_PROFILE_FILE" | sponge "$ACTIVE_PROFILE_FILE"
