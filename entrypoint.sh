#!/bin/bash
if [[ ! -d /.ethereum/geth ]]; then
  geth init genesis.json --datadir .ethereum
else
  echo "/.ethereum/geth is present, skipping init"
fi
geth "${@}"
