#!/bin/bash

# Source the local environment script to set environment variables
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

# Function to create a new profile
create_profile() {
    local profile_name=$1
    local profile_dir="$LOCAL_DATA_DIR/profiles/$profile_name"
    local profile_json="$profile_dir/profile.json"

    # Create profile directory and profile.json file
    mkdir -p "$profile_dir"
    echo "{}" > "$profile_json"

    echo "Profile '$profile_name' created successfully."
}

prompt_for_profile_name() {
    local profile_name=""
    while true; do
        read -p "Enter a new profile name: " profile_name

        # Validation checks
        if [ -z "$profile_name" ]; then
            echo "Error: Profile name cannot be empty. Please try again." >&2
            continue
        fi

        local profile_dir="$LOCAL_DATA_DIR/profiles/$profile_name"
        if [ -d "$profile_dir" ]; then
            echo "Error: Profile '$profile_name' already exists. Please try a different name." >&2
            continue
        fi

        echo "$profile_name"
        break
    done
}

if [ -z "$PROFILE_NAME" ]; then
    PROFILE_NAME=$(prompt_for_profile_name)
fi

create_profile "$PROFILE_NAME"
