# syntax=docker/dockerfile:1
from ubuntu

ARG GETH_BIN
ARG ACCOUNT_KEYSTORE
ARG GENESIS_FILE

COPY ${GETH_BIN}/geth ./geth
COPY ${ACCOUNT_KEYSTORE} ./.ethereum/keystore/.
COPY ${GENESIS_FILE} ./genesis.json

ENTRYPOINT ["./geth", "--genesis", "genesis.json", "--mine", "--txpool.lifetime", "12s", "--txpool.pricebump", "5"]
