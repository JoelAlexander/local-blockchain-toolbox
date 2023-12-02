#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"
gethPath=$($SCRIPT_DIR/install-geth.sh)
geth="$gethPath/geth"
clef="$gethPath/clef"
chainName=$1

if [ -z $chainName ]
then
  echo "Must enter a chain name" && exit 1
fi

chainDir="$LOCAL_DATA_DIR/chains/$chainName"
if [ -d "$chainDir" ]
then
  echo "Chain with name $chainName already exists: $chainDir" && exit 1
fi

mkdir -p $chainDir

#echo -n "Enter a password for the new sealing account: "
#read password
#sealerPassword=password.txt
#echo $password > $chainDir/$sealerPassword

# TODO: All of the cases where we have a genesis file but we aren't a sealer
$clef newaccount --keystore "$LOCAL_DATA_DIR/keystore"
#sealerAccount=$(echo $newAccountOutput | awk '{ print $11 }')
#sealerKeystore=$(realpath --relative-to=$chainDir $(echo $newAccountOutput | awk '{ print $18 }'))

#echo -n "Enter a chain ID for the blockchain genesis: "
#read chainId

#genesisAndConfig=$(npx hardhat makeGenesis\
#  --chain-id $chainId\
#  --sealer-address $sealerAccount)

#echo $genesisAndConfig | jq '.genesis' > $chainDir/genesis.json
#echo $genesisAndConfig | jq '.config' > $chainDir/config.json

#$SCRIPT_DIR/create-bootnode.sh $chainName
