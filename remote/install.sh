#!/bin/bash
scriptPath=$(dirname $(realpath $0))
$scriptPath/build.sh &&\
scp local-blockchain-node.tar.gz ubuntu@joelalexander.me:~/. &&\
ssh ubuntu@joelalexander.me 'tar -xvzf local-blockchain-node.tar.gz' &&\
ssh ubuntu@joelalexander.me
