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
if [ ! -d $gethName ]; then
  if [ ! -f $gethPackage]; then
    echo "Downloading geth from $gethDownload" && curl $gethDownload --output $gethPackage
  fi
  echo "Unpacking geth" && tar -xzf $gethPackage || exit
else
  echo "Using geth at $gethName"
fi

# Reads from the .env file, reusing values that it can, and creating what's needed.
bootnodeKey=$([ -f .env ] && awk -F'=' '/^BOOTNODE_KEY/ { print $2 }' .env | head -1)
if [ -z "${bootnodeKey}" ]; then
  bootnodeKey=bootnode.key
  bootnodeEnode=$(bootnode -genkey bootnode.key -writeaddress)
else
  bootnodeEnode=$([ -f .env ] && awk -F'=' '/^BOOTNODE_ENODE/ { print $2 }' .env | head -1)
  if [ -z "${bootnodeEnode}" ]; then
    bootnodeEnode=$(bootnode -nodekey $bootnodeKey -writeaddress)
  fi
fi

sealerPassword=$([ -f .env ] && awk -F'=' '/^SEALER_PASSWORD/ { print $2 }' .env | head -1)
if [ -z "${sealerPassword}" ]; then
  # TODO: The key is unlocked with no password, so is only as secure as the host password
  echo -n "Enter a password for the new sealing account: "
  read password
  sealerPassword=password.txt
  echo $password > password.txt
fi

genesisFile=$([ -f .env ] && awk -F'=' '/^GENESIS_FILE/ { print $2 }' .env | head -1)
if [ -z "${genesisFile}" ]; then

  # TODO: All of the cases where we have a genesis file but we aren't a sealer
  newAccountOutput=$(geth account new --password $sealerPassword --datadir .)
  sealerAccount=$(echo $newAccountOutput | awk '{ print $11 }')
  sealerKeystore=$(realpath --relative-to=. $(echo $newAccountOutput | awk '{ print $18 }'))

  echo -n "Enter a chain ID for the blockchain genesis: "
  read chainId
  genesisFile=genesis.json
  node make-genesis.js $chainId $sealerAccount > genesis.json
else
  chainId=$([ -f .env ] && awk -F'=' '/^CHAIN_ID/ { print $2 }' .env | head -1)
  sealerAccount=$([ -f .env ] && awk -F'=' '/^SEALER_ACCOUNT/ { print $2 }' .env | head -1)
  sealerKeystore=$([ -f .env ] && awk -F'=' '/^SEALER_KEYSTORE/ { print $2 }' .env | head -1)
  # TODO: Need to read chain id from geneis in the case that there is
  # a valid genesis file in .env but not a chain id.
fi

# Create the images we'll need and start them
docker build -f bootnode/Dockerfile -t bootnode:latest\
  --build-arg GETH_BIN="$gethName"\
  --build-arg BOOTNODE_KEY=$bootnodeKey\
  .

docker build -f rpcnode/Dockerfile -t rpcnode:latest\
  --build-arg GETH_BIN="$gethName"\
  --build-arg GENESIS_FILE=genesis.json\
  --build-arg CHAIN_ID=$chainId\
  .

docker build -f sealingnode/Dockerfile -t sealingnode:latest\
  --build-arg GETH_BIN="$gethName"\
  --build-arg ACCOUNT_ADDRESS=$sealerAccount\
  --build-arg ACCOUNT_KEYSTORE=$sealerKeystore\
  --build-arg GENESIS_FILE=$genesisFile\
  --build-arg PASSWORD_FILE=$sealerPassword\
  --build-arg CHAIN_ID=$chainId\
  .

echo "BOOTNODE_ENODE=$bootnodeEnode" > .env
echo "BOOTNODE_KEY=$bootnodeKey" >> .env
echo "GENESIS_FILE=$genesisFile" >> .env
echo "SEALER_ACCOUNT=$sealerAccount" >> .env
echo "SEALER_KEYSTORE=$sealerKeystore" >> .env
echo "SEALER_PASSWORD=$sealerPassword" >> .env
echo "CHAIN_ID=$chainId" >> .env

docker-compose up
