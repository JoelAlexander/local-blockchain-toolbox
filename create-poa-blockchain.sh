#!/bin/bash
scriptPath=$(dirname $(realpath $0))
gethName=$($scriptPath/install-geth.sh)
geth="$scriptPath/$gethName/geth"
environmentFile=$1

sealerPassword=$(jq -r '.sealerPassword' $environmentFile)
if [ "$sealerPassword" = 'null' ]
then
  # TODO: The key is unlocked with no password, so is only as secure as the host password
  echo -n "Enter a password for the new sealing account: "
  read password
  sealerPassword=password.txt
  echo $password > $scriptPath/$sealerPassword
  jq --arg sealerPassword $sealerPassword\
    '.sealerPassword |= $sealerPassword'\
    $environmentFile | sponge $environmentFile
fi

genesisFile="$scriptPath/genesis.json"
if [ ! -f $genesisFile ]
then

  # TODO: All of the cases where we have a genesis file but we aren't a sealer
  newAccountOutput=$($geth account new --password "$scriptPath/$sealerPassword" --datadir $scriptPath)
  sealerAccount=$(echo $newAccountOutput | awk '{ print $11 }')
  sealerKeystore=$(realpath --relative-to=$scriptPath $(echo $newAccountOutput | awk '{ print $18 }'))

  echo -n "Enter a chain ID for the blockchain genesis: "
  read chainId
  creatorFile="$scriptPath/creator.json"

  npx hardhat makeGenesis --chain-id $chainId --sealer-address $sealerAccount --genesis-file $genesisFile --creator-file $creatorFile

  jq --argjson chainId $chainId\
    --arg sealerAccount $sealerAccount\
    --arg sealerKeystore $sealerKeystore\
    --arg creatorFile $creatorFile\
    '.sealerAccount |= $sealerAccount | .sealerKeystore |= $sealerKeystore | .creatorFile |= $creatorFile'\
    $environmentFile | sponge $environmentFile

  # TODO: this does not feel right to be here
  blockchainUrl=$(jq -r '.blockchainUrl' $environmentFile)
  creatorPrivateKey=$(jq -r '.privateKey' $scriptPath/$creatorFile)
  jq --null-input\
    --arg creatorPrivateKey $creatorPrivateKey\
    --argjson chainId $chainId\
    --arg blockchainUrl $blockchainUrl\
    '{ "chainId": $chainId, "url": $blockchainUrl, "accounts": [ $creatorPrivateKey ]}' | sponge $scriptPath/network.json
fi
