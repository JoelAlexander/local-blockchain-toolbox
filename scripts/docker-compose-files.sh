#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

# Initialize an array to hold Docker Compose file paths
composeFiles=("${REPO_ROOT_DIR}/docker-compose/docker-compose.yml")
composeFiles+=("${REPO_ROOT_DIR}/docker-compose/rpc.yml")

# Add additional Docker Compose files based on the profile configuration
if [ -n "$PROFILE_CHAIN_RPC_DOMAIN" ] && [ "localhost" != "$PROFILE_CHAIN_RPC_DOMAIN" ]; then
    composeFiles+=("${REPO_ROOT_DIR}/docker-compose/rpc-https.yml")
elif [ "localhost" == "$PROFILE_CHAIN_RPC_DOMAIN" ]; then
	composeFiles+=("${REPO_ROOT_DIR}/docker-compose/rpc-localhost.yml")
fi

SEALER_KEYSTORE=$($SCRIPT_DIR/get-keystore.sh $PROFILE_CHAIN_SEALER_ADDRESS)
if [ ! -z "$SEALER_KEYSTORE" ]; then
    composeFiles+=("${REPO_ROOT_DIR}/docker-compose/sealer.yml")
fi

if [ -n "$PROFILE_APP_DOMAIN" ]; then
    composeFiles+=("${REPO_ROOT_DIR}/docker-compose/application.yml")
fi

# Return the array
echo "${composeFiles[@]}"
