#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

CLEF="$GETH_DIR/clef"

get_account_address() {
    local keystoreFile=$1
    local addressInFilename=${keystoreFile##*--}
    echo $addressInFilename
}

prompt_for_keystore() {
    local keystoreFile
    local success=false

    while [ "$success" = false ]; do
        keystoreFile=$($SCRIPT_DIR/get-keystore.sh)
        if [ $? -eq 0 ]; then
            success=true
            echo $keystoreFile
        else
            echo "Invalid selection. Please try again." >&2
        fi
    done
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

update_profile_with_account() {
    local account_address=$1
    local profile_file="$ACTIVE_PROFILE_DIRECTORY/profile.json"

    # Add the account address to the accounts array in the profile JSON
    jq --arg account "$account_address" '.accounts += [$account]' "$profile_file" > temp.json && mv temp.json "$profile_file"
}

# If arguments are provided, use them. Otherwise, prompt for input.
if [ $# -eq 3 ]; then
    ACCOUNT_ADDRESS="$1"
    KEYSTORE_PASSWORD="$2"
    MASTER_PASSWORD="$3"
else
    echo "Select account to attach to profile $ACTIVE_PROFILE" >&2
    ACCOUNT_KEYSTORE=$($SCRIPT_DIR/get-keystore.sh)
    ACCOUNT_ADDRESS=$(get_account_address "$ACCOUNT_KEYSTORE")
    
    echo "Confirm password for account keystore: $ACCOUNT_ADDRESS" >&2
    KEYSTORE_PASSWORD=$(prompt_for_password)

    echo "Confirm master password for profile: $ACTIVE_PROFILE" >&2
    MASTER_PASSWORD=$(prompt_for_password)
fi

$CLEF --keystore "$LOCAL_DATA_DIR/keystore" --configdir "$PROFILE_CLEF_DIR" --chainid "$PROFILE_CHAIN_ID" --suppress-bootwarn setpw $ACCOUNT_ADDRESS <<EOF
$KEYSTORE_PASSWORD
$KEYSTORE_PASSWORD
$MASTER_PASSWORD
EOF
update_profile_with_account "$ACCOUNT_ADDRESS"
