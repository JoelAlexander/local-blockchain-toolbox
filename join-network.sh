#!/bin/bash
domain=$1

# TODO: https? port 443?
sudo tailscale up --login-server https://$domain:443 --operator=$USER
