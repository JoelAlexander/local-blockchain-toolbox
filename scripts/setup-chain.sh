#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

prompt_for_chain_name() {
    while true; do
        local chain_dir=$($SCRIPT_DIR/get-chain.sh)
        if [ $? -eq 1 ]; then
            echo "Error getting chain directory. Please try again."
            continue  
        elif [ -d "$chain_dir" ]; then
            echo "$(basename $chain_dir)"
            break
        else
            echo "No valid chain directory found. Please try again."
            continue
        fi
    done
}

set_chain_in_profile() {
    local chain_name=$1
    local profile_file="$ACTIVE_PROFILE_DIRECTORY/profile.json"

    # Update the profile.json with the chosen chain
    jq --arg chain_name "$chain_name" '.chain = $chain_name' "$profile_file" > "$profile_file.tmp" && mv "$profile_file.tmp" "$profile_file"
    echo "Chain '$chain_name' has been set in the active profile '$ACTIVE_PROFILE'."
}

echo "Select a chain to attach to the active profile:"
CHAIN_NAME=$(prompt_for_chain_name)
set_chain_in_profile "$CHAIN_NAME"

source "${SCRIPT_DIR}/local-env.sh"

echo "Initializing Clef for chain: '$PROFILE_CHAIN_NAME' with chain ID: $PROFILE_CHAIN_ID"

if [ ! -p "$PROFILE_CLEF_DIR/clef.ipc" ]; then
    mkfifo $PROFILE_CLEF_DIR/clef.ipc
fi

$GETH_DIR/clef --keystore $KEYSTORE_DIR --configdir $PROFILE_CLEF_DIR --chainid $PROFILE_CHAIN_ID --suppress-bootwarn init

prompt_for_password() {
    while true; do
        read -s -p "Enter password: " password1 >&2
        echo >&2
        read -s -p "Verify password: " password2 >&2
        echo >&2

        if [ "$password1" == "$password2" ] && [ ${#password1} -ge 10 ]; then
            break
        else
            echo "Passwords do not match or are shorter than 10 characters. Please try again." >&2
        fi
    done

    echo "$password1"
}

SEALER_KEYSTORE=$($SCRIPT_DIR/get-keystore.sh $PROFILE_CHAIN_SEALER_ADDRESS)
if [ ! -z $SEALER_KEYSTORE ]; then
    echo "Sealer keystore found. Do you want to attach the account and set up Clef for automatic signing? (yes/no)" >&2
    read setupClef

    if [ "$setupClef" == "yes" ]; then
        
        echo "Confirm password for account keystore: $PROFILE_CHAIN_SEALER_ADDRESS" >&2
        KEYSTORE_PASSWORD=$(prompt_for_password)

        echo "Confirm master password for profile: $ACTIVE_PROFILE" >&2
        MASTER_PASSWORD=$(prompt_for_password)

        $SCRIPT_DIR/attach-account.sh $PROFILE_CHAIN_SEALER_ADDRESS $KEYSTORE_PASSWORD $MASTER_PASSWORD

        RULES_HASH=$(sha256sum "$REPO_ROOT_DIR/docker-compose/clique-rules.js" | cut -f1)
        $GETH_DIR/clef --keystore $KEYSTORE_DIR --configdir $PROFILE_CLEF_DIR --chainid $PROFILE_CHAIN_ID --suppress-bootwarn attest $RULES_HASH <<EOF
$MASTER_PASSWORD
EOF
        echo "Sealing account successfully set up in active profile: $ACTIVE_PROFILE"
    fi
fi

# Prompt to ask the user whether they want to host the RPC on a public domain or just locally
echo "Do you want to host the RPC on a public domain (requires access to DNS records for DNS challenge)? Type 'yes' for public domain, 'no' for local hosting."
read -p "Your choice (yes/no): " host_rpc_choice

if [ "$host_rpc_choice" == "yes" ]; then
    echo "Please enter the domain you wish to use for the blockchain RPC:"
    read rpc_domain

    # Call the setup-rpc-subdomain.sh script with the entered domain
    "${SCRIPT_DIR}/setup-rpc-subdomain.sh" "$rpc_domain"
else
    "${SCRIPT_DIR}/setup-rpc-subdomain.sh" "localhost"
    echo "RPC set up to run locally."
fi
