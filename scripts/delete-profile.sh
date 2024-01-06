#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

PROFILES_DIR="$LOCAL_DATA_DIR/profiles"
ACTIVE_PROFILE_FILE="$LOCAL_DATA_DIR/active_profile"

# Function to list and select profiles
select_profile() {
    echo "Select a profile to delete:"
    select profile in "$PROFILES_DIR"/*; do
        if [ -n "$profile" ]; then
            echo "$profile"
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
}

profile_to_delete=$(select_profile)

if [ "$(basename "$profile_to_delete")" == "$(cat "$ACTIVE_PROFILE_FILE")" ]; then
    echo "Cannot delete the active profile. Please change the active profile before deleting."
    exit 1
fi

sudo rm -rf "$profile_to_delete"
echo "Profile deleted successfully."
