const path = require('node:path')
const fs = require('fs')
const environment = require('./../environment.json')
const hardhatConfig = require('./../hardhat.config.json')
const utils = require('./utils.js')
const ensUtils = require('./ensUtils.js')

async function deploy() {
  if (!environment.faucetAddress) {
    const signer = await utils.getSigner()
    const transactionCount = await signer.getTransactionCount()
    if (transactionCount !== 0) {
      console.error(`Faucet deployment should be transaction #0 for the creator account`)
    }
    await utils.deployContract('Faucet').then((faucet) => {
      environment.faucetAddress = faucet.address
    })
  } else {
    console.log(`Faucet already deployed to ${environment.faucetAddress}`)
  }

  if (!environment.ensAddress) {
    await utils.deployContract('ENSDeployment').then((ensDeployment) => {
      return ensDeployment.ens()
    }).then((ensAddress) => {
      console.log(`ENS instance at: ${ensAddress}`)
      environment.ensAddress = ensAddress
    })
  } else {
    console.log(`ENS already deployed to ${environment.ensAddress}`)
  }

  const [publicLabel, rootNode] = ensUtils.leafLabelAndNode('public')
  const [faucetLabel, publicNode] = ensUtils.leafLabelAndNode('faucet.public')
  const faucetNode = ensUtils.hash('faucet.public')
  console.log(`Claiming .public`)
  await ensUtils.claimSubnode(rootNode, publicLabel).then((receipt) => {
    console.log(`Claiming faucet.public`)
    return ensUtils.claimSubnode(publicNode, faucetLabel).then((receipt) => {
      console.log(`Setting resolver for faucet.public to the public resolver`)
      return ensUtils.setPublicResolver(faucetNode).then((receipt) => {
        console.log(`Setting address for faucet.public to facuet at ${environment.faucetAddress}`)
        return ensUtils.setPublicResolverAddr(faucetNode, environment.faucetAddress)
      })
    })
  })

  fs.writeFileSync(path.join(__dirname, '..', 'environment.json'), JSON.stringify(environment, null, 2))
}

deploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
