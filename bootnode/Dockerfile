# syntax=docker/dockerfile:1
from ubuntu

ARG GETH_BIN
ARG BOOTNODE_KEY

ADD ${GETH_BIN}/bootnode ./bootnode
COPY ${BOOTNODE_KEY} ./bootnode.key

ENTRYPOINT ./bootnode -nodekey bootnode.key
