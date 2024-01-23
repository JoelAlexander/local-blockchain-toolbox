#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

# Check if there are no attached agents and exit if true
if [ ${#ATTACHED_AGENTS[@]} -eq 0 ]; then
    echo "No attached agents found. Exiting."
    exit 1
fi

echo "Select an agent to detach:"
select agent in "${ATTACHED_AGENTS[@]}"; do
    if [ -n "$agent" ]; then
        agent_name="${agent%@*}"
        break
    else
        echo "Invalid selection. Please try again."
    fi
done

profile_file="$ACTIVE_PROFILE_FILE"
temp_file="${profile_file}.tmp"

# Remove the agent from the agents array in the profile JSON
jq --arg agent_name "$agent_name" 'del(.agents[] | select(.name == $agent_name))' "$profile_file" > "$temp_file" && mv "$temp_file" "$profile_file"
echo "Agent $agent_name detached successfully."
