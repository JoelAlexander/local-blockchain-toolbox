#!/bin/bash

SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

# Check if there's an active profile with an attached chain
if [ -z "$PROFILE_CHAIN_NAME" ]; then
    echo "No active chain attached to the profile. Please attach a chain first."
    exit 1
fi

if [ -z "$PROFILE_ACTIVE_ACCOUNT" ]; then
    echo "No active account attached to the profile. Please attach an account first."
    exit 1
fi

# Path to the ENS JSON file in the active chain directory
ENS_JSON_FILE="$LOCAL_DATA_DIR/chains/$PROFILE_CHAIN_NAME/ens.json"
PROFILE_FILE="$ACTIVE_PROFILE_DIRECTORY/profile.json"

# Function to list and select an existing ENS
select_existing_ens() {
    if [ ! -f "$ENS_JSON_FILE" ] || [ -z "$(jq -r 'keys[]' "$ENS_JSON_FILE")" ]; then
        echo "No existing ENS configurations found."
        return 1
    fi

    echo "Available ENS names:"
    jq -r 'keys[]' "$ENS_JSON_FILE"

    local selected_ens
    read -p "Select an ENS name: " selected_ens

    if ! jq -e --arg ensName "$selected_ens" '.[$ensName] // empty' "$ENS_JSON_FILE" > /dev/null; then
        echo "Invalid ENS name selected."
        return 1
    fi

    jq --arg ensName "$selected_ens" '.ens = $ensName' "$PROFILE_FILE" > temp.json && mv temp.json "$PROFILE_FILE"
}

# Function to validate Ethereum address (basic validation)
is_valid_ethereum_address() {
    if [[ $1 =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        return 0
    else
        return 1
    fi
}

prompt_for_password() {
    while true; do
        read -s -p "Enter password: " password1 >&2
        echo >&2
        if [ ${#password1} -ge 10 ]; then
            break
        else
            echo "Password is shorter than 10 characters. Please try again." >&2
        fi
    done
    echo "$password1"
}

# Function to deploy and import a new ENS
deploy_and_import_new_ens() {
    echo "Enter the password for account $PROFILE_ACTIVE_ACCOUNT"
    account_password=$(prompt_for_password)

    echo "Deploying new ENS...this may take a few minutes..."
    local ens_deployment_output
    local ens_deployment_address
    local import_output
    local ens_name
    ens_deployment_output=$(ACCOUNT_PASSWORD=$account_password npx hardhat deployEns)
    ens_deployment_address=$(echo "$ens_deployment_output" | tail -n 1)
    if ! is_valid_ethereum_address "$ens_deployment_address"; then
        exit 1
    fi

    import_output=$("${SCRIPT_DIR}/import-ens.sh" "$ens_deployment_address")
    ens_name=$(echo "$import_output" | grep -oP '(?<=ENS imported successfully: ).*?(?= ->)')
    jq --arg ensName "$ens_name" '.ens = $ensName' "$PROFILE_FILE" > temp.json && mv temp.json "$PROFILE_FILE"
	echo "ENS configuration updated for the active profile."
}


# Main logic
echo "Do you want to use an existing ENS or deploy a new one? (existing/deploy)"
read -p "Choice: " choice

case $choice in
    existing)
        if ! select_existing_ens; then
            echo "Failed to select existing ENS. Exiting."
            exit 1
        fi
        ;;
    deploy)
        if ! deploy_and_import_new_ens; then
            echo "Failed to deploy and import new ENS. Exiting."
            exit 1
        fi
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac
