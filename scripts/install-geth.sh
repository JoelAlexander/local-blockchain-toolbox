#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

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

gethInstallFolder="$LOCAL_DATA_DIR/geth"
gethName="geth-alltools-linux-${variant}-1.13.5-916d6a44"
gethPackage="$gethName.tar.gz"
gethDownload="https://gethstore.blob.core.windows.net/builds/$gethPackage"
gethPath="$gethInstallFolder/$gethName"
gethPackagePath="$gethInstallFolder/$gethPackage"
if [[ ! -d $gethPath ]]; then
  curl $gethDownload --output $gethPackagePath && tar -xzf $gethPackagePath --directory $gethInstallFolder
  rm $gethPackagePath
fi

echo $gethPath
