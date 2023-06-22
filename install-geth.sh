#!/bin/bash
scriptPath=$(dirname $(realpath $0))

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
gethInstallFolder="$scriptPath/host"
gethName="geth-alltools-linux-${variant}-1.10.26-e5eb32ac"
gethPackage="$gethName.tar.gz"
gethDownload="https://gethstore.blob.core.windows.net/builds/$gethPackage"
gethPath="$gethInstallFolder/$gethName"
gethPackagePath="$gethInstallFolder/$gethPackage"
if [[ ! -d $gethPath ]]; then
  curl $gethDownload --output $gethPackagePath && tar -xzf $gethPackagePath --directory $gethInstallFolder
  rm $gethPackagePath
fi

echo $gethPath
