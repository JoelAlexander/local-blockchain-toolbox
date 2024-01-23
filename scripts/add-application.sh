#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

prompt_for_git_repo() {
    local git_repo=""
    while [ -z "$git_repo" ]; do
        read -p "Enter Git repository URL: " git_repo
        if [ -z "$git_repo" ]; then
            echo "Repository URL cannot be empty. Please try again."
        fi
    done
    echo "$git_repo"
}

clone_and_build_app() {
    local repo_url=$1
    local app_name=$(basename "$repo_url" .git)
    local app_dir="$APP_STORAGE_DIR/$app_name"

    if [ ! -d "$app_dir" ]; then
        echo "Cloning repository..."
        git clone "$repo_url" "$app_dir" || { echo "Failed to clone repository."; exit 1; }

        if [ ! -d "$app_dir/dist" ]; then
            echo "Building the application..."
            (cd "$app_dir" && npm update && npm install && npm run contracts && npm run buildProd) || { echo "Build failed."; exit 1; }
        fi
        echo "Application added successfully."
    else
        echo "Application already exists."
    fi
}

git_repo=$(prompt_for_git_repo)
clone_and_build_app "$git_repo"
