#!/bin/bash
scriptPath=$(dirname $(realpath $0))
HEADSCALE_PATH=$scriptPath/headscale/config;docker compose -f headscale.yml stop
