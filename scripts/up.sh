#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

composeFilesRaw=$(${SCRIPT_DIR}/docker-compose-files.sh | tail -n 1)
composeFiles=($composeFilesRaw)
composeFileArgs=$(printf -- "-f %s " "${composeFiles[@]}")

nginx_http_conf=""
nginx_stream_conf='server {
  listen 30303 udp;
  proxy_pass rpcnode:30303;
  proxy_responses 0;
}

server {
  listen 30303;
  proxy_pass rpcnode:30303;
  proxy_responses 0;
}'

prompt_for_clef_password() {
    while true; do
        # Prompt for the password and read it silently
        read -s -p "Enter Clef password: " password1 >&2
        echo >&2

        # Check if passwords match and are of acceptable length
        if [ ${#password1} -ge 10 ]; then
            echo "$password1"
            break
        else
            echo "Password is shorter than 10 characters. Please try again." >&2
        fi
    done
}

export RPC_DOMAIN="$PROFILE_CHAIN_RPC_DOMAIN"
export RPC_ETHEREUM_DIR="$PROFILE_ETHEREUM_DIR/rpc"
export GENESIS_FILE_PATH="$PROFILE_CHAIN_GENESIS_FILE"
export CHAIN_ID="$PROFILE_CHAIN_ID"
export BOOTNODE_ENODE="$DEFAULT_BOOTNODE_ENODE"
export BOOTNODE_KEY="$DEFAULT_BOOTNODE_KEY"

# TODO replace with dynamic app domain
PROFILE_APP_DOMAIN="localhost"
APP_DOMAIN=$PROFILE_APP_DOMAIN
if [ "localhost" != "$RPC_DOMAIN" ]; then
  CERTIFICATE_SETUP_OUTPUT=$(bash "$SCRIPT_DIR/setup-domain.sh" "$RPC_DOMAIN")
  export RPC_FULLCHAIN=$(echo "$CERTIFICATE_SETUP_OUTPUT" | sed -n '1p')
  export RPC_PRIVKEY=$(echo "$CERTIFICATE_SETUP_OUTPUT" | sed -n '2p')
  nginx_http_conf+=$(sed -e "s/{{DOMAIN}}/$RPC_DOMAIN/" -e "s/{{ORIGIN_DOMAIN}}/$APP_DOMAIN/" "${REPO_ROOT_DIR}/docker-compose/templates/rpc-https_http.conf.template")
  nginx_http_conf+=$'\n'
  nginx_http_conf+=$(cat "${REPO_ROOT_DIR}/docker-compose/https-redirect_http.conf")
  nginx_http_conf+=$'\n'
else
  nginx_http_conf+=$(cat "${REPO_ROOT_DIR}/docker-compose/rpc-localhost_http.conf")
  nginx_http_conf+=$'\n'
fi

for file in "${composeFiles[@]}"; do
  if [[ $file =~ ${LOCAL_DATA_DIR}/docker/([^@]+)@([^:]+):([0-9]+)\.yml ]]; then
    app_name=${BASH_REMATCH[1]}
    domain=${BASH_REMATCH[2]}
    port=${BASH_REMATCH[3]}

    if [ "localhost" != "$domain" ]; then
      CERTIFICATE_SETUP_OUTPUT=$(bash "$SCRIPT_DIR/setup-domain.sh" "$domain")
      fullchain_var="${domain^^}_FULLCHAIN"
      privkey_var="${domain^^}_PRIVKEY"
      export "$fullchain_var"=$(echo "$CERTIFICATE_SETUP_OUTPUT" | sed -n '1p')
      export "$privkey_var"=$(echo "$CERTIFICATE_SETUP_OUTPUT" | sed -n '2p')
      nginx_http_conf+=$(sed -e "s|{{APP_NAME}}|$app_name|" -e "s|{{DOMAIN}}|$domain|" -e "s|{{PORT}}|$port|" "${REPO_ROOT_DIR}/docker-compose/templates/app-https_http.conf.template")
      nginx_http_conf+=$'\n'
    else
      nginx_http_conf+=$(sed -e "s|{{APP_NAME}}|$app_name|" -e "s|{{DOMAIN}}|$domain|" -e "s|{{PORT}}|$port|" "${REPO_ROOT_DIR}/docker-compose/templates/app-localhost_http.conf.template")
      nginx_http_conf+=$'\n'
    fi
  fi
done

if [[ " ${composeFiles[*]} " =~ " ${REPO_ROOT_DIR}/docker-compose/sealer.yml " ]]; then
  export CLEF_PASSWORD=$(prompt_for_clef_password)
  export SEALER_KEYSTORE=$($SCRIPT_DIR/get-keystore.sh $PROFILE_CHAIN_SEALER_ADDRESS)
  export CLEF_RULES="$REPO_ROOT_DIR/docker-compose/clique-rules.js"
  export SEALER_ETHEREUM_DIR="$PROFILE_ETHEREUM_DIR/sealer"
  export SEALER_ADDRESS="$PROFILE_CHAIN_SEALER_ADDRESS"
  export CLEF_DIR="$PROFILE_CLEF_DIR"
  export CLEF_IPC="$PROFILE_CLEF_DIR/clef.ipc"
fi

if [[ " ${composeFiles[*]} " =~ " ${REPO_ROOT_DIR}/docker-compose/application.yml " ]]; then
  if [ "localhost" != "$APP_DOMAIN"]; then
    nginx_http_conf+=$(sed -e "s/{{DOMAIN}}/$APP_DOMAIN/" "${REPO_ROOT_DIR}/docker-compose/templates/app-https_http.conf.template")
    nginx_http_conf+=$'\n'
  else
    nginx_http_conf+=$(cat "${REPO_ROOT_DIR}/docker-compose/app-localhost_http.conf")
    nginx_http_conf+=$'\n'
  fi
fi

export NGINX_HTTP_CONF="$nginx_http_conf"
export NGINX_STREAM_CONF="$nginx_stream_conf"

cd "$REPO_ROOT_DIR"

echo $nginx_http_conf

echo "Running Docker Compose with the following configuration: $composeFileArgs"
docker-compose -p "local-blockchain-toolbox" $composeFileArgs up -d
