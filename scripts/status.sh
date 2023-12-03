#!/bin/bash

SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

echo "Blockchain Node Manager Status Report"
echo "====================================="

echo "Available Profiles:"
if [ -d "$LOCAL_DATA_DIR/profiles" ]; then
    ls "$LOCAL_DATA_DIR/profiles"
else
    echo "No profiles connected."
fi
echo

# List Connected Chains
echo "Connected Chains:"
if [ -d "$LOCAL_DATA_DIR/chains" ]; then
    ls "$LOCAL_DATA_DIR/chains"
else
    echo "No chains connected."
fi
echo

# List Accounts
echo "Accounts:"
if [ -d "$LOCAL_DATA_DIR/keystore" ]; then
    ls "$LOCAL_DATA_DIR/keystore"
else
    echo "No accounts found."
fi
echo

# List Nodes
echo "Nodes:"
if [ -d "$LOCAL_DATA_DIR/nodes" ]; then
    ls "$LOCAL_DATA_DIR/nodes"
else
    echo "No nodes configured."
fi
echo

# List SSH Keys
echo "SSH Keys:"
if [ -d "$LOCAL_DATA_DIR/.ssh" ]; then
    ls "$LOCAL_DATA_DIR/.ssh"
else
    echo "No SSH keys available."
fi
echo

# Other relevant details
# This can include additional checks or summaries based on your specific setup and requirements.

echo "Status report completed."
