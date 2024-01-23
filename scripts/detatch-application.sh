#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

# Check if there are no attached applications and exit if true
if [ ${#ATTACHED_APPLICATIONS[@]} -eq 0 ]; then
    echo "No attached applications found. Exiting."
    exit 1
fi

echo "Select an application to detach:"
select app in "${ATTACHED_APPLICATIONS[@]}"; do
    if [ -n "$app" ]; then
        application="$app"
        break
    else
        echo "Invalid selection. Please try again."
    fi
done

app_name="${application%@*}"
profile_file="$ACTIVE_PROFILE_FILE"
temp_file="${profile_file}.tmp"

# Remove the application from the applications array in the profile JSON
jq --arg app_name "$app_name" 'del(.applications[] | select(.name == $app_name))' "$profile_file" > "$temp_file" && mv "$temp_file" "$profile_file"
echo "Application detached successfully."
