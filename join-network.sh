#!/bin/bash
domain=$1

# TODO: https? port 443?
tailscale up --login-server http://$domain:8080
