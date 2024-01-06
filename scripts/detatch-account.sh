#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

# Function to list and select accounts from the active profile
select_account() {
    local profile_file="$ACTIVE_PROFILE_DIRECTORY/profile.json"
    local accounts=($(jq -r '.accounts[]' "$profile_file"))
    
    if [ ${#accounts[@]} -eq 0 ]; then
        echo "No accounts attached to the profile." >&2
        exit 1
    fi

    echo "Select an account to detach:" >&2
    select account in "${accounts[@]}"; do
        if [ -n "$account" ]; then
            echo "$account"
            break
        else
            echo "Invalid selection. Please try again." >&2
        fi
    done
}

# Function to update profile by removing the selected account
detach_account_from_profile() {
    local account_address=$1
    local profile_file="$ACTIVE_PROFILE_DIRECTORY/profile.json"
    local temp_file="${profile_file}.tmp"

    # Remove the selected account address from the accounts array in the profile JSON
    jq --arg account "$account_address" 'del(.accounts[] | select(. == $account))' "$profile_file" > "$temp_file" && mv "$temp_file" "$profile_file"
    echo "Account $account_address detached from profile."
}


echo "Detaching an account from profile $ACTIVE_PROFILE" >&2
account_to_detach=$(select_account)

# Perform the detachment operation
detach_account_from_profile "$account_to_detach"
