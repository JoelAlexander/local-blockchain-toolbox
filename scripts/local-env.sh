#!/bin/bash
SCRIPT_DIR=$(dirname "$0")

get_git_root_dir() {
    git rev-parse --show-toplevel 2>/dev/null
}

# Set the repository root directory
export REPO_ROOT_DIR=$(get_git_root_dir)
if [ -z "$REPO_ROOT_DIR" ]; then
    echo "Error: Must run this script within a Git repository."
    exit 1
fi

export LOCAL_DATA_DIR="$REPO_ROOT_DIR/.local"

# Function to create a directory if it does not exist
create_directory_if_not_exists() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo "Created directory: $dir"
    fi
}

mkdir -p "$LOCAL_DATA_DIR/profiles"
ACTIVE_PROFILE_FILE_PATH="$LOCAL_DATA_DIR/active_profile"
prompt_for_new_profile() {
    echo "No profiles found. Please create a new profile."
    local new_profile_name=""
    while [ -z "$new_profile_name" ]; do
        read -p "Enter new profile name: " new_profile_name
      if [ -z "$new_profile_name" ]; then
          echo "Profile name cannot be empty. Please try again."
      fi
    done
    echo "$new_profile_name" > "$ACTIVE_PROFILE_FILE_PATH"
}

prompt_for_active_profile() {
    echo "No active profile set. Please choose an active profile from the list below:"
    select profile in "$LOCAL_DATA_DIR/profiles"/*; do
        echo $(basename "$profile") > "$ACTIVE_PROFILE_FILE_PATH"
        break
    done
}

if [ -f "$ACTIVE_PROFILE_FILE_PATH" ]; then
    ACTIVE_PROFILE=$(cat "$ACTIVE_PROFILE_FILE_PATH")
else
    if [ -z "$(ls -A "$LOCAL_DATA_DIR/profiles")" ]; then
       prompt_for_new_profile
    else
       prompt_for_active_profile
    fi
    ACTIVE_PROFILE=$(cat "$ACTIVE_PROFILE_FILE_PATH")
fi

export PROFILES_DIR="$LOCAL_DATA_DIR/profiles"
export ACTIVE_PROFILE_DIRECTORY="$PROFILES_DIR/$ACTIVE_PROFILE"
mkdir -p $ACTIVE_PROFILE_DIRECTORY

export ACTIVE_PROFILE_FILE="$ACTIVE_PROFILE_DIRECTORY/profile.json"

if [ ! -f "$ACTIVE_PROFILE_FILE" ]; then
    echo "{}" > "$ACTIVE_PROFILE_FILE"
fi

# Create the active profile directory and file if they don't exist
create_directory_if_not_exists "$ACTIVE_PROFILE_DIRECTORY"
[ ! -f "$ACTIVE_PROFILE_FILE" ] && echo "{}" > "$ACTIVE_PROFILE_FILE"

# TODO: Assumes linux
machine=$(uname -m)
if [ $machine == "x86_64" ]; then
  variant="amd64"
elif [ $machine == "aarch64" ]; then
  variant="arm64"
else
  echo "$machine is not a supported platform."
  exit
fi

gethInstallFolder="$LOCAL_DATA_DIR/geth"
gethVersion="1.13.5-916d6a44"
gethName="geth-alltools-linux-${variant}-${gethVersion}"
gethPackage="$gethName.tar.gz"
gethDownload="https://gethstore.blob.core.windows.net/builds/$gethPackage"
export GETH_DIR="$gethInstallFolder/$gethName"
gethPackagePath="$gethInstallFolder/$gethPackage"
if [[ ! -d $GETH_DIR ]]; then
  curl $gethDownload --output $gethPackagePath && tar -xzf $gethPackagePath --directory $gethInstallFolder
  rm $gethPackagePath
fi

build_docker_images_if_needed() {

    if [ -z "$(docker image ls local-blockchain-toolbox/geth | grep -v REPOSITORY)" ]; then
        echo "Building Docker image: local-blockchain-toolbox/geth"
        docker build -f $REPO_ROOT_DIR/docker/geth/Dockerfile -t local-blockchain-toolbox/geth --build-arg GETH_BIN="${GETH_DIR#$REPO_ROOT_DIR/}" $REPO_ROOT_DIR
    fi

    if [ -z "$(docker image ls local-blockchain-toolbox/clef | grep -v REPOSITORY)" ]; then
        echo "Building Docker image: local-blockchain-toolbox/clef"
        docker build -f $REPO_ROOT_DIR/docker/clef/Dockerfile -t local-blockchain-toolbox/clef --build-arg GETH_BIN="${GETH_DIR#$REPO_ROOT_DIR/}" $REPO_ROOT_DIR
    fi

    if [ -z "$(docker image ls local-blockchain-toolbox/nginx | grep -v REPOSITORY)" ]; then
        echo "Building Docker image: local-blockchain-toolbox/nginx"
        docker build -f $REPO_ROOT_DIR/docker/nginx/Dockerfile -t local-blockchain-toolbox/nginx $REPO_ROOT_DIR
    fi
}

# Call the function to ensure Docker images are built
build_docker_images_if_needed

PROFILE_CLEF_DIR="$ACTIVE_PROFILE_DIRECTORY/clef"
PROFILE_ETHEREUM_DIR="$ACTIVE_PROFILE_DIRECTORY/.ethereum"

export PROFILE_CLEF_DIR
export PROFILE_ETHEREUM_DIR

mkdir -p $PROFILE_CLEF_DIR $PROFILE_ETHEREUM_DIR

# Set chain-specific environment variables
PROFILE_CHAIN_NAME=$(jq -r '.chain // empty' "$ACTIVE_PROFILE_FILE")
[ -n "$PROFILE_CHAIN_NAME" ] && export PROFILE_CHAIN_NAME

PROFILE_CHAIN_RPC_DOMAIN=$(jq -r '.rpc.domain // empty' "$ACTIVE_PROFILE_FILE")
[ -n "$PROFILE_CHAIN_RPC_DOMAIN" ] && export PROFILE_CHAIN_RPC_DOMAIN

PROFILE_CHAIN_GENESIS_FILE="$LOCAL_DATA_DIR/chains/$PROFILE_CHAIN_NAME/genesis.json"
[ -f "$PROFILE_CHAIN_GENESIS_FILE" ] && export PROFILE_CHAIN_GENESIS_FILE

# Check if the accounts array exists and is not null
if jq -e '.accounts // empty' "$ACTIVE_PROFILE_FILE" > /dev/null; then
    PROFILE_LINKED_ACCOUNTS=($(jq -r '.accounts[]' "$ACTIVE_PROFILE_FILE"))
    if [ -z "$PROFILE_ACTIVE_ACCOUNT" ] && [ ${#PROFILE_LINKED_ACCOUNTS[@]} -gt 0 ]; then
        export PROFILE_ACTIVE_ACCOUNT="${PROFILE_LINKED_ACCOUNTS[0]}"
    fi

    export PROFILE_LINKED_ACCOUNTS=("${PROFILE_LINKED_ACCOUNTS[@]}")
else
    PROFILE_LINKED_ACCOUNTS=()  # Initialize as an empty array if accounts are not available
    export PROFILE_LINKED_ACCOUNTS
fi

export CHAINS_DIR="$LOCAL_DATA_DIR/chains"

if [ -f "$PROFILE_CHAIN_GENESIS_FILE" ]; then
    extraData=$(jq -r '.extraData' "$PROFILE_CHAIN_GENESIS_FILE")
    export PROFILE_CHAIN_ID=$(jq -r '.config.chainId // empty' "$PROFILE_CHAIN_GENESIS_FILE")
    export PROFILE_CHAIN_SEALER_ADDRESS="0x${extraData:66:40}"  # Extract 40 characters after the first 66 characters
fi

ENS_NAME=$(jq -r '.ens // empty' "$ACTIVE_PROFILE_FILE")
if [ ! -z "$ENS_NAME" ]; then
    export ENS_NAME
fi

ENS_JSON_FILE="$LOCAL_DATA_DIR/chains/$PROFILE_CHAIN_NAME/ens.json"

# Check if ENS JSON file exists and read the address associated with the ENS name
if [ -f "$ENS_JSON_FILE" ]; then
    ENS_ADDRESS=$(jq -r --arg ensName "$ENS_NAME" '.[$ensName] // empty' "$ENS_JSON_FILE")
    if [ -n "$ENS_ADDRESS" ]; then
        export ENS_ADDRESS
    fi
else
    echo "Warning: ENS configuration file ($ENS_JSON_FILE) not found."
fi

export BOOTNODES_DIR="$LOCAL_DATA_DIR/bootnodes"
create_directory_if_not_exists "$BOOTNODES_DIR"
export DEFAULT_BOOTNODE_KEY="$BOOTNODES_DIR/default/bootnode.key"
if [ ! -f "$DEFAULT_BOOTNODE_KEY" ]; then
    mkdir -p "$BOOTNODES_DIR/default"
    $GETH_DIR/bootnode -genkey "$DEFAULT_BOOTNODE_KEY"
fi

bootnodeKey=$(cat "$DEFAULT_BOOTNODE_KEY")
export DEFAULT_BOOTNODE_ENODE=$($GETH_DIR/bootnode -nodekeyhex $bootnodeKey -writeaddress)

export CERTS_DIR="$LOCAL_DATA_DIR/certbot"
create_directory_if_not_exists $CERTS_DIR > /dev/null

export KEYSTORE_DIR="$LOCAL_DATA_DIR/keystore"
create_directory_if_not_exists $KEYSTORE_DIR > /dev/null

create_directory_if_not_exists "$LOCAL_DATA_DIR" >/dev/null
create_directory_if_not_exists "$LOCAL_DATA_DIR/.ssh" >/dev/null
create_directory_if_not_exists "$LOCAL_DATA_DIR/chains" >/dev/null
create_directory_if_not_exists "$LOCAL_DATA_DIR/profiles" >/dev/null
create_directory_if_not_exists "$LOCAL_DATA_DIR/geth" >/dev/null
create_directory_if_not_exists "$LOCAL_DATA_DIR/nodes" >/dev/null
create_directory_if_not_exists "$LOCAL_DATA_DIR/ubuntu" >/dev/null

export APP_STORAGE_DIR="$LOCAL_DATA_DIR/applications"
mkdir -p "$APP_STORAGE_DIR"

if jq -e '.applications // empty' "$ACTIVE_PROFILE_FILE" > /dev/null; then
    ATTACHED_APPLICATIONS=($(jq -r '.applications[] | "\(.name)@\(.domain):\(.port)"' "$ACTIVE_PROFILE_FILE"))
else
    ATTACHED_APPLICATIONS=()  # Initialize as an empty array if applications are not available
fi
export ATTACHED_APPLICATIONS

if [ -n "$PROFILE_CHAIN_RPC_DOMAIN" ]; then
    if [ "localhost" == "$PROFILE_CHAIN_RPC_DOMAIN" ]; then
        USED_ENDPOINTS=("$PROFILE_CHAIN_RPC_DOMAIN:80")
    else
        USED_ENDPOINTS=("$PROFILE_CHAIN_RPC_DOMAIN:443")
    fi
fi
for app in "${ATTACHED_APPLICATIONS[@]}"; do
    app_endpoint="${app##*@}" # Extracts everything after '@'
    USED_ENDPOINTS+=("$app_endpoint")
done
export USED_ENDPOINTS

export DOCKER_TEMP_DIR="$LOCAL_DATA_DIR/docker"
mkdir -p "$DOCKER_TEMP_DIR"
