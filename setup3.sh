#!/bin/bash



hostname=$(openssl rand -hex 16)
macAddress=$(nmcli dev show $wirelessInterface | awk '/GENERAL.HWADDR/ { print $2 }')
gateway=$(nmcli dev show $wirelessInterface | awk '/IP4.GATEWAY/ { print $2 }')
ipAddress=$(nmcli dev show $wirelessInterface | awk '/IP4.ADDRESS/ { print $2 }' | sed -e 's/\/.*//')

echo "Access the admin panel on your router: http://$gateway"
echo "Give $macAddress a static IP of $ipAddress with a hostname of $hostname"
echo "Forward port 80 for $ipAddress"

# TODO: Ensure that this is completed, either by user input or some check.

echo "After this is complete, enter your domain: "
read domain

wanAddress="???"
echo "Change A record for $domain to $wanAddress"

# TODO: Ensure that this is completed, either by user input or some check.

sudo certbot certonly --manual --preferred-challenges=dns -d "*.$domain" --register-unsafely-without-email

echo "Change A record for $domain to $ipAddress"
