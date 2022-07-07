#!/bin/bash

wirelessInterface=$(./connect-wireless-interface.sh)
macAddress=$(nmcli dev show $wirelessInterface | awk '/GENERAL.HWADDR/ { print $2 }')
gateway=$(nmcli dev show $wirelessInterface | awk '/IP4.GATEWAY/ { print $2 }')
ipAddress=$(nmcli dev show $wirelessInterface | awk '/IP4.ADDRESS/ { print $2 }' | sed -e 's/\/.*//')

echo "Before proceding: "
echo "Access the admin panel on your router: http://$gateway"
echo "Give $macAddress a static IP of $ipAddress"

domain=$([ -f .env ] && awk -F'=' '/^DOMAIN/ { print $2 }' .env | head -1)
if [ -z "$domain" ]; then
  read -p "Enter your domain: " domain
  sudo certbot certonly --manual --preferred-challenges=dns -d "*.$domain" --register-unsafely-without-email
  echo "DOMAIN=$domain" >> .env
fi

certs="/etc/letsencrypt/live/$domain"
fullchain=$([ -f .env ] && awk -F'=' '/^CERT_FULLCHAIN/ { print $2 }' .env | head -1)
privkey=$([ -f .env ] && awk -F'=' '/^CERT_PRIVKEY/ { print $2 }' .env | head -1)
if [ -z "$fullchain" ] && [ -z "$privkey" ]; then

  if sudo test ! -f "$certs/fullchain.pem" && sudo test ! -f "$certs/privkey.pem"
  then
    echo "SSL certificates for $domain not found"
  fi

  fullchain=$(sudo readlink -f "$certs/fullchain.pem")
  privkey=$(sudo readlink -f "$certs/privkey.pem")
  echo "CERT_FULLCHAIN=$fullchain" >> .env
  echo "CERT_PRIVKEY=$privkey" >> .env
fi

cat nginx.conf.template | sed "s/{{DOMAIN}}/$domain/" > nginx.conf
