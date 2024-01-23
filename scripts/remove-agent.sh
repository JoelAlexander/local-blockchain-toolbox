#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

list_and_select_agents() {
    echo "Select an agent to remove:"
    select agent_dir in "$AGENTS_DIR"/*; do
        if [ -n "$agent_dir" ]; then
            echo $(basename "$agent_dir")
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
}

if [ -z "$(ls -A "$AGENTS_DIR")" ]; then
    echo "No agents found."
    exit 1
fi

agent_name=$(list_and_select_agents)
agent_dir="$AGENTS_DIR/$agent_name"

rm -rf "$agent_dir"
echo "Agent $agent_name removed successfully."
