#!/bin/bash
scriptPath=$(dirname $(realpath $0))
environmentFile=$1

headscaleConfig=$scriptPath/headscale/config
mkdir -p $headscaleConfig
touch $headscaleConfig/db.sqlite

jq --arg headscaleConfig $headscaleConfig\
  '.headscaleConfig |= $headscaleConfig'\
  $environmentFile | sponge $environmentFile
