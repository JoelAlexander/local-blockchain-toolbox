#!/bin/bash
scriptPath=$(dirname $(realpath $0))

# Lazily create empty environment file if it doesn't exist already
environmentFile="$scriptPath/environment.json"
if [ ! -f $environmentFile ]
then
  echo '{}' > $environmentFile
fi

echo $environmentFile
