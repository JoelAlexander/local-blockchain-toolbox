#!/usr/bin/env node
const ethers = require('ethers')

const args = process.argv.slice(2)

const chainId = parseInt(args[0])
const sealerAddress = args[1].replace("0x", "")
const extraData = `0x0000000000000000000000000000000000000000000000000000000000000000${sealerAddress}0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000`

const genesis = {
  "config": {
    "chainId": chainId,
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "constantinopleBlock": 0,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "berlinBlock": 0,
    "londonBlock": 0,
    "clique": {
      "period": 6,
      "epoch": 30000
    }
  },
  "difficulty": "1",
  "gasLimit": "8000000",
  "extraData": extraData,
  "nonce": "0x1",
  "alloc": {
    "0x0e936b7F8f6F4FEd74aAd5Be183651666E617654": {
      "balance": "100000000000000000"
    },
    "0x0Ff4f87B22b795a672fC12884a09087EBdE021cB": {
      "balance": "1000000000000000000000000"
    }
  }
}

console.log(JSON.stringify(genesis))
