#!/bin/bash

SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

NEW_PROFILE=$1

# Function to select a profile from the existing profiles
select_profile() {
    local profiles=("$LOCAL_DATA_DIR/profiles"/*)
    select profile_path in "${profiles[@]}"; do
        if [[ -n "$profile_path" ]]; then
            echo $(basename "$profile_path")
            break
        else
            echo "Invalid selection. Please try again." >&2
        fi
    done
}

if [ -z "$NEW_PROFILE" ]; then
    echo "Please select a profile:"
    NEW_PROFILE=$(select_profile)
    if [ -z "$NEW_PROFILE" ]; then
        echo "No profile selected. Exiting." >&2
        exit 1
    fi
fi

echo "$NEW_PROFILE" > "$LOCAL_DATA_DIR/active_profile"

echo "Active profile set to $NEW_PROFILE."
