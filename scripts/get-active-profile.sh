#!/bin/bash

SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

if [ -f "$LOCAL_DATA_DIR/active_profile" ]; then
    ACTIVE_PROFILE=$(cat "$LOCAL_DATA_DIR/active_profile")
    echo "Active Profile: $ACTIVE_PROFILE"
else
    echo "No active profile set."
fi
