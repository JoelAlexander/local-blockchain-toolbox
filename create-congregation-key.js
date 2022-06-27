#!/usr/bin/env node
const ethers = require('ethers')
const signer = ethers.Wallet.createRandom()
console.log(signer.privateKey)
