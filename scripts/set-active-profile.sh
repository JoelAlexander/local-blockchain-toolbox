#!/bin/bash

SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

NEW_PROFILE=$1

if [ -z "$NEW_PROFILE" ]; then
    echo "Usage: $0 <profile_name>"
    exit 1
fi

echo "$NEW_PROFILE" > "$LOCAL_DATA_DIR/active_profile"

echo "Active profile set to $NEW_PROFILE."
