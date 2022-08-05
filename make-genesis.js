#!/usr/bin/env node
const path = require('node:path')
const ethers = require('ethers')
const ethJsUtil = require('ethereumjs-util')
const fs = require('fs');

const args = process.argv.slice(2)

const chainId = parseInt(args[0])
const sealerAddress = args[1].replace("0x", "")
const genesisFilePath = args[2]
const creatorFilePath = args[3]

const creatorWallet = ethers.Wallet.createRandom()
const extraData = `0x0000000000000000000000000000000000000000000000000000000000000000${sealerAddress}0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000`
const genesis = {
  "config": {
    "chainId": chainId,
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip150Hash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "constantinopleBlock": 0,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "berlinBlock": 0,
    "londonBlock": 0,
    "clique": {
      "period": 6
    }
  },
  "difficulty": "1",
  "gasLimit": "8000000",
  "extraData": extraData,
  "nonce": "0x0",
  "alloc": {}
}

// TODO: Remove and replace with creator's personal account
// TODO: This can happen in hyphen setup script as a transaction to personal wallet.
// genesis.alloc["0x0e936b7F8f6F4FEd74aAd5Be183651666E617654"] = {
//   "balance": "100000000000000000"
// }

const getContractAddress = (address, nonce) => {
  return ethJsUtil.bufferToHex(
    ethJsUtil.generateAddress(
      ethJsUtil.toBuffer(address),
      ethJsUtil.toBuffer(nonce)))
}

const creatorBalance = "1000000000000000000"
const creatorAlloc = "1000000000000000000000000"
genesis.alloc[creatorWallet.address] = {
  "balance": creatorBalance
}

genesis.alloc[getContractAddress(creatorWallet.address, 0)] = {
  "balance": creatorAlloc
}

const creator = { privateKey: creatorWallet.privateKey }

fs.writeFileSync(creatorFilePath, JSON.stringify(creator))
fs.writeFileSync(genesisFilePath, JSON.stringify(genesis))
