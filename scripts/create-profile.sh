#!/bin/bash

SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

PROFILE_NAME=$1

if [ -z "$PROFILE_NAME" ]; then
    echo "Usage: $0 <profile_name>"
    exit 1
fi

PROFILE_DIR="$LOCAL_DATA_DIR/profiles/$PROFILE_NAME"
mkdir -p "$PROFILE_DIR/clef"

echo "Profile $PROFILE_NAME created."
