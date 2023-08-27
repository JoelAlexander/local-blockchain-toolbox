#!/bin/bash
if [[ ! -d /.ethereum/geth ]]; then
  geth --datadir .ethereum init genesis.json
else
  echo "/.ethereum/geth is present, skipping init"
fi
geth "${@}"
