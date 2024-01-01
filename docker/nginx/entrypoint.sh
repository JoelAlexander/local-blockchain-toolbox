#!/bin/bash
# entrypoint.sh for Nginx container

# Write the Nginx configurations to their respective files
echo "$NGINX_HTTP_CONF" > /etc/nginx/conf.d/http.conf
echo "$NGINX_STREAM_CONF" > /etc/nginx/conf.d/stream.conf

# Start Nginx in the foreground
nginx -g 'daemon off;'
