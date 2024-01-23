#!/bin/bash
read -p "Enter the name for the new agent: " agent_name
agent_dir="$HOME/$agent_name"

if [ -d "$agent_dir" ]; then
    echo "Error: An agent with the name '$agent_name' already exists."
    exit 1
fi

mkdir -p "$agent_dir"
cd "$agent_dir"
git init

npm init -y

cat <<EOF > index.js
console.log("Starting the agent...");

const runLoop = () => {
    console.log("Agent $agent_name is running...");

    if (shouldExit()) {
        console.log("Exiting the agent...");
        clearInterval(intervalId);
    }
};

const shouldExit = () => {
    // Implement your exit condition here
    return false;
};

const intervalId = setInterval(runLoop, 1000);
EOF

echo "Agent $agent_name created successfully."
