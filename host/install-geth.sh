#!/bin/bash

scriptPath=$(dirname $(realpath $0))
localBlockchainPath=$($scriptPath/get-blockchain-directory.sh)

# TODO: Assumes linux
machine=$(uname -m)
if [ $machine == "x86_64" ]; then
  variant="amd64"
elif [ $machine == "aarch64" ]; then
  variant="arm64"
else
  echo "$machine is not a supported platform."
  exit
fi

# Pull geth if needed to local directory.
# TODO: Probably could clean up this geth install to be more respectful
gethName="geth-alltools-linux-${variant}-1.10.19-23bee162"
gethPackage="$gethName.tar.gz"
gethDownload="https://gethstore.blob.core.windows.net/builds/$gethPackage"
gethPath="$localBlockchainPath/$gethName"
gethPackagePath="$localBlockchainPath/$gethPackage"
if [[ ! -d $gethPath || ! -f $gethPackagePath ]]; then
  curl $gethDownload --output $gethPackagePath && tar -xzf $gethPackagePath --directory $localBlockchainPath
fi

echo $gethName
