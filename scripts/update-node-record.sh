#!/bin/bash

SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

# Check for the jq command
if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Please install jq to use this script."
    exit 1
fi

# Function to update or add a property in a JSON file
update_json_property() {
    local file=$1
    local key=$2
    local value=$3
    local dir

    # Get the directory part of the file path
    dir=$(dirname "$file")

    # Ensure the directory exists
    mkdir -p "$dir"

    # Update or create the file with the new property
    if [ -f "$file" ]; then
        jq ".$key = \"$value\"" "$file" > tmp.$$.json && mv tmp.$$.json "$file"
    else
        jq -n ".$key = \"$value\"" > "$file"
    fi
}

# Main script logic
if [ $# -lt 2 ]; then
    echo "Usage: $0 <hostname> <property_key> <property_value>"
    exit 1
fi

HOSTNAME=$1
PROPERTY_KEY=$2
PROPERTY_VALUE=$3

# Define the path for the individual node record file
NODE_RECORD_FILE="$LOCAL_DATA_DIR/nodes/$HOSTNAME.json"

# Update or add the property in the node's JSON file
update_json_property "$NODE_RECORD_FILE" "$PROPERTY_KEY" "$PROPERTY_VALUE"

echo "Node record for $HOSTNAME has been updated."
