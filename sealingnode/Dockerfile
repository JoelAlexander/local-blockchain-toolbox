# syntax=docker/dockerfile:1
from ubuntu

ARG GENESIS_FILE
ARG GETH_BIN
ARG ACCOUNT_KEYSTORE
ARG PASSWORD_FILE

COPY ${GENESIS_FILE} ./genesis.json

COPY ${GETH_BIN}/* ./gethbin/
ENV PATH="/gethbin:$PATH"
RUN geth init genesis.json --datadir .ethereum

COPY ${ACCOUNT_KEYSTORE} /.ethereum/${ACCOUNT_KEYSTORE}
COPY ${PASSWORD_FILE} ./password.txt

ENTRYPOINT ["geth", "--ipcdisable", "--datadir", ".ethereum", "--mine", "--txpool.lifetime", "12s", "--txpool.pricebump", "5"]
