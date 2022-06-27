# syntax=docker/dockerfile:1
from ubuntu

ARG GETH_BIN
ARG GENESIS_FILE

COPY ${GETH_BIN}/geth ./geth
COPY ${GENESIS_FILE} ./genesis.json

ENTRYPOINT ["./geth", "--genesis", "genesis.json", "--txpool.lifetime", "12s", "--txpool.pricebump", "5"]
