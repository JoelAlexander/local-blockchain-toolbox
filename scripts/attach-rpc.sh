#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

# Function to prompt for domain and validate input
prompt_for_domain() {
    while true; do
        read -p "Enter the domain name for RPC: " domain
        if [ -z "$domain" ]; then
            echo "Domain name cannot be empty. Please try again."
            continue
        fi
        echo "$domain"
        break
    done
}

# Function to update the active profile with the RPC domain
update_profile_with_rpc_domain() {
    local domain=$1
    local profile_file="$ACTIVE_PROFILE_DIRECTORY/profile.json"

    # Update the profile.json with the RPC domain
    jq --arg domain "$domain" '.rpc.domain = $domain' "$profile_file" > "$profile_file.tmp" && mv "$profile_file.tmp" "$profile_file"
    echo "RPC domain '$domain' has been set in the active profile '$ACTIVE_PROFILE'."
}

# Main script execution
echo "Setting up the RPC domain for the active profile..."

# Prompt for the domain
RPC_DOMAIN=$(prompt_for_domain)

# Call setup-domain.sh to ensure valid certificates and capture the output
CERTIFICATE_SETUP_OUTPUT=$(bash "$SCRIPT_DIR/setup-domain.sh" "$RPC_DOMAIN")
FULLCHAIN_PATH=$(echo "$CERTIFICATE_SETUP_OUTPUT" | sed -n '1p')
PRIVKEY_PATH=$(echo "$CERTIFICATE_SETUP_OUTPUT" | sed -n '2p')

# Update the active profile with the RPC domain
update_profile_with_rpc_domain "$RPC_DOMAIN"
