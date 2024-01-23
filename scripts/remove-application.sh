#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

list_and_select_applications() {
    select app in "$APP_STORAGE_DIR"/*; do
        if [ -n "$app" ]; then
            echo $(basename "$app")
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
}


is_app_in_use() {
    local app=$1
    for profile in "$PROFILES_DIR"/*; do
        if jq -e --arg app "$app" '.applications // [] | any(.name == $app)' "$profile/profile.json" > /dev/null; then
            return 0
        fi
    done
    return 1
}

if [ -z "$(ls -A "$APP_STORAGE_DIR")" ]; then
    echo "No applications found."
    exit 1
fi

echo "Select an application to remove:"
app_name=$(list_and_select_applications)

if is_app_in_use "$app_name"; then
    echo "Application '$app_name' is in use by a profile. Cannot delete."
    exit 1
else
    app_dir="$APP_STORAGE_DIR/$app_name"
    rm -rf "$app_dir"
    echo "Application $app_dir removed successfully."
fi
