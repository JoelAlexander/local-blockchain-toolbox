#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"


echo "Select an application to attach:"
select app in "$APP_STORAGE_DIR"/*; do
    if [ -n "$app" ]; then
        app_name=$(basename "$app")
        break
    else
        echo "Invalid selection. Please try again."
    fi
done

domain=""
port=""
read -p "Enter domain to host '$app_name' (default: localhost): " domain
domain=${domain:-localhost}

if [ "$domain" == "localhost" ]; then
    port="80"
else
    port="443"
    ${SCRIPT_DIR}/setup-domain.sh "$domain"
fi

application_endpoint="${app_name}@${domain}:${port}"
while true; do
    if [[ ! $port =~ ^[0-9]+$ ]]; then
        echo "Invalid port: $port. Please enter an integer."
        read -p "Enter a valid port: " port
    else
        port_collision=false
        for endpoint in "${USED_ENDPOINTS[@]}"; do
            endpoint_port=${endpoint##*:}
            if [[ "$endpoint_port" == "$port" ]]; then
                port_collision=true
                break
            fi
        done

        if [[ $port_collision == true ]]; then
            echo "Port $port is already in use. Please choose a different port."
            read -p "Enter a different port: " port
        else
            application_endpoint="${app_name}@${domain}:${port}"
            break
        fi
    fi
done


profile_file="$ACTIVE_PROFILE_FILE"
temp_file="${profile_file}.tmp"
jq --arg app "$app_name" --arg domain "$domain" --argjson port "$port" \
    'if .applications then .applications += [{"name": $app, "domain": $domain, "port": $port}] else . + {"applications": [{"name": $app, "domain": $domain, "port": $port}]} end' \
    "$profile_file" > "$temp_file" && mv "$temp_file" "$profile_file"
echo "Application attached successfully."
