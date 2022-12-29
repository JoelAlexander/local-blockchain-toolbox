#!/bin/bash
scriptPath=$(dirname $(realpath $0))
gethPath=$($scriptPath/install-geth.sh)
geth="$gethPath/geth"
chainName=$1

chainDir="$scriptPath/chains/$chainName"
if [ -d "$chainDir" ]
then
  echo "Chain with name $chainName already exists: $chainDir" && exit 1
fi

mkdir -p $chainDir

echo -n "Enter a password for the new sealing account: "
read password
sealerPassword=password.txt
echo $password > $chainDir/$sealerPassword

# TODO: All of the cases where we have a genesis file but we aren't a sealer
newAccountOutput=$($geth account new --password "$chainDir/$sealerPassword" --datadir $chainDir)
sealerAccount=$(echo $newAccountOutput | awk '{ print $11 }')
sealerKeystore=$(realpath --relative-to=$chainDir $(echo $newAccountOutput | awk '{ print $18 }'))

echo -n "Enter a chain ID for the blockchain genesis: "
read chainId

npx hardhat makeGenesis\
  --chain-id $chainId\
  --sealer-address $sealerAccount\
  --chain-dir $chainDir

$scriptPath/create-bootnode.sh $chainName
