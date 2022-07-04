#!/bin/bash

tar -czvf local-blockchain-node.tar.gz\
  bootnode\
  rpcnode\
  sealingnode\
  setup.sh\
  setup2.sh\
  make-genesis.js\
  docker-compose.yml\
