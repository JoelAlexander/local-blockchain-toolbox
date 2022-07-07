#!/bin/bash

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
if [[ ! -d $gethName || ! -f $gethPackage ]]; then
  curl $gethDownload --output $gethPackage && tar -xzf $gethPackage
fi

echo "$gethName"
