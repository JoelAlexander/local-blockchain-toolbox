#!/bin/bash
scriptPath=$(dirname $(realpath $0))
domain=$1
headscaleConfig=$scriptPath/host/headscale/config
mkdir -p $headscaleConfig
touch $headscaleConfig/db.sqlite
cat $scriptPath/templates/headscale-config.yaml.template | sed -e "s/{{DOMAIN}}/$domain/" > $headscaleConfig/config.yaml

HEADSCALE_PATH=$(readlink -f $headscaleConfig);docker compose -f headscale.yml up -d &&\
	docker compose -f headscale.yml exec -it headscale headscale namespaces create nodes &&\
	docker compose -f headscale.yml stop
