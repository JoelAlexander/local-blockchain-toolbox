#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

prompt_for_git_repo() {
    local git_repo=""
    while [ -z "$git_repo" ]; do
        read -p "Enter Git repository URL for the agent: " git_repo
        if [ -z "$git_repo" ]; then
            echo "Repository URL cannot be empty. Please try again."
        fi
    done
    echo "$git_repo"
}

clone_or_update_agent() {
    local repo_url=$1
    local agent_name=$(basename "$repo_url" .git)
    local agent_dir="$AGENTS_DIR/$agent_name"

    if [ ! -d "$agent_dir" ]; then
        echo "Cloning repository..."
        git clone "$repo_url" "$agent_dir" || { echo "Failed to clone repository."; exit 1; }
    else
        echo "Updating existing agent..."
        (cd "$agent_dir" && git pull) || { echo "Failed to update agent."; exit 1; }
    fi
    echo "Agent '$agent_name' added/updated successfully."
}

git_repo=$(prompt_for_git_repo)
clone_or_update_agent "$git_repo"
