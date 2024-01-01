#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

# Get the array of Docker Compose files
composeFiles=($(${SCRIPT_DIR}/docker-compose-files.sh))

# Convert the array to a string of arguments for docker-compose
composeFileArgs=$(printf -- "-f %s " "${composeFiles[@]}")

# Change directory to REPO_ROOT_DIR
cd "$REPO_ROOT_DIR"

# Execute the Docker Compose down command
echo "Stopping Docker Compose services..."
docker-compose -p "local-blockchain-toolbox" $composeFileArgs down
