#!/bin/bash
scriptPath=$(dirname $(realpath $0))
chainName=$1

chainDir="$scriptPath/chains/$chainName"
if [ -d "$chainDir" ]
then
	rm -rf $chainDir
	$scriptPath/stop-blockchain.sh $chainName stop
	$scriptPath/stop-blockchain.sh $chainName remove
else
	echo "Chain not found: $chainName"
fi