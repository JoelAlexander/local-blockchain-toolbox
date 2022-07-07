#!/bin/bash

scriptPath=$(dirname $(realpath $0))
localBlockchainPath=$($scriptPath/get-blockchain-directory.sh)

wirelessInterface=$($scriptPath/connect-wireless-interface.sh)
macAddress=$(nmcli dev show $wirelessInterface | awk '/GENERAL.HWADDR/ { print $2 }')
gateway=$(nmcli dev show $wirelessInterface | awk '/IP4.GATEWAY/ { print $2 }')
ipAddress=$(nmcli dev show $wirelessInterface | awk '/IP4.ADDRESS/ { print $2 }' | sed -e 's/\/.*//')

echo "Before proceding: "
echo "Access the admin panel on your router: http://$gateway"
echo "Give $macAddress a static IP of $ipAddress"

domain=$($scriptPath/get-local-blockchain-env.sh DOMAIN)
if [ -z "$domain" ]; then
  read -p "Enter your domain: " domain
  sudo certbot certonly --manual --preferred-challenges=dns -d "*.$domain" --register-unsafely-without-email
  echo "DOMAIN=$domain" >> $localBlockchainPath/.env
fi

certs="/etc/letsencrypt/live/$domain"
fullchain=$($scriptPath/get-local-blockchain-env.sh CERT_FULLCHAIN)
privkey=$($scriptPath/get-local-blockchain-env.sh CERT_PRIVKEY)
if [ -z "$fullchain" ] && [ -z "$privkey" ]; then

  if sudo test ! -f "$certs/fullchain.pem" && sudo test ! -f "$certs/privkey.pem"
  then
    echo "SSL certificates for $domain not found"
  fi

  fullchain=$(sudo readlink -f "$certs/fullchain.pem")
  privkey=$(sudo readlink -f "$certs/privkey.pem")
  echo "CERT_FULLCHAIN=$fullchain" >> $localBlockchainPath/.env
  echo "CERT_PRIVKEY=$privkey" >> $localBlockchainPath/.env
fi

cat $scriptPath/nginx.conf.template | sed "s/{{DOMAIN}}/$domain/" > $localBlockchainPath/nginx.conf
