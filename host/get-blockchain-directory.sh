#!/bin/bash
if [ ! -d ~/.local-blockchain ]
then
  mkdir ~/.local-blockchain
fi

echo $(realpath ~/.local-blockchain)
