#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Must run $0 as root."
  exit
fi

source ~/.profile

if ! [ -x "$(command -v geth)" ]; then
  echo "geth not on path"
else
  echo "geth on path"
fi
