# syntax=docker/dockerfile:1
from ubuntu

ARG GETH_BIN
COPY ./docker/clef/entrypoint.sh /
COPY ${GETH_BIN}/* ./gethbin/
ENV PATH="/gethbin:$PATH"
ENTRYPOINT ["./entrypoint.sh"]
