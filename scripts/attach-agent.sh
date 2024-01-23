#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

select_agent() {
    select agent_dir in "$AGENTS_DIR"/*; do
        if [ -n "$agent_dir" ]; then
            echo $(basename "$agent_dir")
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
}

select_account() {
    account_path=$(bash "${SCRIPT_DIR}/get-keystore.sh")
    echo ${account_path##*--}
}

echo "Select an agent to attach:"
agent_name=$(select_agent | tail -n 1)

echo "Select an Ethereum account for the agent:"
agent_account=$(select_account)

profile_file="$ACTIVE_PROFILE_FILE"
temp_file="${profile_file}.tmp"

# Attach the agent to the profile
jq --arg agent_name "$agent_name" --arg agent_account "$agent_account" \
    'if .agents then .agents += [{"name": $agent_name, "account": $agent_account}] else . + {"agents": [{"name": $agent_name, "account": $agent_account}]} end' \
    "$profile_file" > "$temp_file" && mv "$temp_file" "$profile_file"

echo "Agent $agent_name attached successfully."
