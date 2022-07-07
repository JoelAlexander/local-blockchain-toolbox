# syntax=docker/dockerfile:1
from ubuntu

ARG GETH_BIN
ADD ${GETH_BIN}/bootnode ./bootnode
ENTRYPOINT ["./bootnode", "-nodekey", "bootnode.key"]
