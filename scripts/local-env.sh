#!/bin/bash

get_git_root_dir() {
    git rev-parse --show-toplevel 2>/dev/null
}

REPO_ROOT_DIR=$(get_git_root_dir)
if [ -z "$REPO_ROOT_DIR" ]; then
    echo "Error: Must run this script within a Git repository."
    exit 1
fi

export LOCAL_DATA_DIR="$REPO_ROOT_DIR/.local"

create_directory_if_not_exists() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo "Created directory: $dir"
    fi
}

# Add this in the local-env.sh script
PROFILE_FILE="$LOCAL_DATA_DIR/active_profile"
if [ -f "$PROFILE_FILE" ]; then
    ACTIVE_PROFILE=$(cat "$PROFILE_FILE")
else
	echo default > $PROFILE_FILE
    ACTIVE_PROFILE="default"
fi

export CLEF_DIR="$LOCAL_DATA_DIR/profiles/$ACTIVE_PROFILE/clef"
mkdir -p "$CLEF_DIR"

create_directory_if_not_exists "$LOCAL_DATA_DIR" >/dev/null
create_directory_if_not_exists "$LOCAL_DATA_DIR/.ssh" >/dev/null
create_directory_if_not_exists "$LOCAL_DATA_DIR/chains" >/dev/null
create_directory_if_not_exists "$LOCAL_DATA_DIR/profiles" >/dev/null
create_directory_if_not_exists "$LOCAL_DATA_DIR/geth" >/dev/null
create_directory_if_not_exists "$LOCAL_DATA_DIR/keystore" >/dev/null
create_directory_if_not_exists "$LOCAL_DATA_DIR/nodes" >/dev/null
create_directory_if_not_exists "$LOCAL_DATA_DIR/ubuntu" >/dev/null
