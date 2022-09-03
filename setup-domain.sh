#!/bin/bash
scriptPath=$(dirname $(realpath $0))
environmentFile=$1

domain=$(jq -r '.domain' $environmentFile)
if [ "$domain" == 'null' ]
then
  echo -n "Enter your domain: "
  read domain
  sudo certbot certonly --manual --preferred-challenges=dns -d "$domain" -d "blockchain.$domain" --register-unsafely-without-email
  jq --arg domain $domain '.domain |= $domain' $environmentFile | sponge $environmentFile
else
  echo "Using domain: $domain"
fi

# TODO: Detect certificates better than just guessing
certs="/etc/letsencrypt/live/$domain"
fullchain=$(jq -r '.fullchain' $environmentFile)
privkey=$(jq -r '.privkey' $environmentFile)
if [ "$fullchain" = 'null' ] && [ "$privkey" = 'null' ]
then
  if sudo test ! -f "$certs/fullchain.pem" && sudo test ! -f "$certs/privkey.pem"
  then
    echo "SSL certificates for $domain not found"
  fi

  fullchain=$(sudo readlink -f "$certs/fullchain.pem")
  privkey=$(sudo readlink -f "$certs/privkey.pem")
  sudo chown $USER $fullchain $privkey
  jq --arg fullchain $fullchain\
    --arg privkey $privkey\
    '.fullchain |= $fullchain | .privkey |= $privkey'\
    $environmentFile | sponge $environmentFile
else
  echo "Using certificate files: $fullchain, $privkey"
fi

blockchainUrl=$(jq -r '.blockchainUrl' $environmentFile)
if [ $blockchainUrl == 'null' ]
then
  blockchainUrl="https://blockchain.$domain/"
  jq --arg blockchainUrl $blockchainUrl '.blockchainUrl |= $blockchainUrl'\
    $environmentFile | sponge $environmentFile
fi
