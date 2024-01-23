#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

# Initialize an array to hold Docker Compose file paths
composeFiles=("${REPO_ROOT_DIR}/docker-compose/docker-compose.yml")
composeFiles+=("${REPO_ROOT_DIR}/docker-compose/rpc.yml")

# Add additional Docker Compose files based on the profile configuration
if [ -n "$PROFILE_CHAIN_RPC_DOMAIN" ] && [ "localhost" != "$PROFILE_CHAIN_RPC_DOMAIN" ]; then
	rpcUrl="http://$PROFILE_CHAIN_RPC_DOMAIN:443/"
    composeFiles+=("${REPO_ROOT_DIR}/docker-compose/rpc-https.yml")
elif [ "localhost" == "$PROFILE_CHAIN_RPC_DOMAIN" ]; then
	rpcUrl="http://localhost:80/"
	composeFiles+=("${REPO_ROOT_DIR}/docker-compose/rpc-localhost.yml")
fi

SEALER_KEYSTORE=$($SCRIPT_DIR/get-keystore.sh $PROFILE_CHAIN_SEALER_ADDRESS)
if [ ! -z "$SEALER_KEYSTORE" ]; then
    composeFiles+=("${REPO_ROOT_DIR}/docker-compose/sealer.yml")
fi

if [ -n "$PROFILE_APP_DOMAIN" ]; then
    composeFiles+=("${REPO_ROOT_DIR}/docker-compose/application.yml")
fi

rm -f $DOCKER_TEMP_DIR/*
echo "{\"url\":\"$rpcUrl\",\"chainId\":\"$PROFILE_CHAIN_ID\",\"ens\":\"$ENS_ADDRESS\"}" > $DOCKER_TEMP_DIR/chain-config.json

generate_app_yaml() {
    local app="$1"
    local domain="${app##*@}"
    local name="${app%%@*}"
    local port="${domain##*:}"
    domain="${domain%%:*}"

    local template
    if [ "$domain" == "localhost" ]; then
        template="${REPO_ROOT_DIR}/docker-compose/templates/application-localhost.yml.template"
    else
        template="${REPO_ROOT_DIR}/docker-compose/templates/application-https.yml.template"
    fi

    local output="$DOCKER_TEMP_DIR/$name@$domain:$port.yml"
    sed -e "s/{{PORT}}/$port/g" \
        -e "s/{{DOMAIN}}/$domain/g" \
        -e "s/{{APPLICATION_NAME}}/$name/g" \
        -e "s|{{APPLICATION_PATH}}|$APP_STORAGE_DIR/$name/dist|g" \
        -e "s|{{CHAIN_CONFIG_PATH}}|$DOCKER_TEMP_DIR/chain-config.json|g" \
        $template > $output

    echo $output
}


# Generate YAML files for each attached application
for app in "${ATTACHED_APPLICATIONS[@]}"; do
    app_yaml=$(generate_app_yaml "$app")
    composeFiles+=("$app_yaml")
done

# Return the array
echo "${composeFiles[@]}"
