#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

CLEF="$GETH_DIR/clef"

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

if [ $# -eq 1 ]; then
    PASSWORD=$1
else
    PASSWORD=$(prompt_for_password)
fi

NEW_ACCOUNT_OUTPUT=$(echo $PASSWORD | $CLEF newaccount --keystore "$LOCAL_DATA_DIR/keystore" --suppress-bootwarn)
NEW_ACCOUNT_ADDRESS=$(echo "$NEW_ACCOUNT_OUTPUT" | grep -o 'Generated account \S*' | awk '{print $3}')

echo $NEW_ACCOUNT_ADDRESS
