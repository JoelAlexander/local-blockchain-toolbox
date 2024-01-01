#!/bin/bash
scriptPath=$(dirname $(realpath $0))
domain=$1

sudo certbot certonly --manual --preferred-challenges=dns -d "$domain" -d "headscale.$domain" -d "blockchain.$domain" --register-unsafely-without-email
