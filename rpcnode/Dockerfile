# syntax=docker/dockerfile:1
from ubuntu

ARG GENESIS_FILE
ARG GETH_BIN

COPY ${GENESIS_FILE} ./genesis.json

COPY ${GETH_BIN}/* ./gethbin/
ENV PATH="/gethbin:$PATH"
RUN geth init genesis.json --datadir .ethereum

ENTRYPOINT ["geth", "--datadir", ".ethereum", "--http", "--http.addr", "0.0.0.0", "--http.vhosts", "*", "--http.corsdomain", "*", "--http.api", "eth,net,rpc,web3,txpool", "--txpool.lifetime", "12s", "--txpool.pricebump", "5"]
