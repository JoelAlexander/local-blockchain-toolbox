#!/bin/bash
scriptPath=$(dirname $(realpath $0))
genesisFile=$1
username=$2
host=$3

scp $genesisFile $"$username@$host:~/."
