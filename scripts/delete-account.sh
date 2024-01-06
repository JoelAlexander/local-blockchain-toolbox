#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

KEYSTORE_DIR="$LOCAL_DATA_DIR/keystore"
PROFILES_DIR="$LOCAL_DATA_DIR/profiles"

# Function to list and select keystore files
select_keystore() {
    select account in "$KEYSTORE_DIR"/*; do
        if [ -n "$account" ]; then
            echo "$account"
            break
        else
            echo "Invalid selection. Please try again." >&2
        fi
    done
}

get_account_address() {
    local keystoreFile=$1
    local addressInFilename=${keystoreFile##*--}
    echo $addressInFilename
}

echo "Select an account to delete:"
account_to_delete=$(select_keystore)
account_address=$(get_account_address "$account_to_delete")
echo $account_address
echo $account_to_delete

# Function to check if an account is in use by a profile
is_account_in_use() {
    local account=$1
    local profile=$2

    if jq -e '.accounts // empty' "$profile" > /dev/null; then
        if jq -e --arg account "0x$account" '.accounts[] == $account' "$profile" > /dev/null; then
            return 0 # Account is in use
        fi
    fi
    return 1 # Account is not in use
}

for profile in "$PROFILES_DIR"/*; do
    if is_account_in_use "$account_address" "$profile/profile.json"; then
        echo "Account '$account_address' is in use by profile '$(basename "$profile")'. Cannot delete."
        exit 1
    fi
done

rm "$account_to_delete"
echo "Account deleted successfully."
