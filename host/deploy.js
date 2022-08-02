const path = require('node:path')
const fs = require('fs')
const environment = require('./environment.json')
const hardhatConfig = require('./hardhat.config.json')
const utils = require('./utils.js')

async function deploy() {
  const signer = await utils.getSigner()
  const transactionCount = await signer.getTransactionCount()
  if (transactionCount === 0) {
    await utils.deployContract('Faucet')
  } else {
    console.log(`Transaction count non-zero: skipping Faucet deployment`)
  }

  if (!environment.ensAddress) {
    await utils.deployContract('ENSDeployment').then((ensDeployment) => {
      return ensDeployment.ens()
    }).then((ensAddress) => {
      console.log(`ENS instance at: ${ensAddress}`)
      environment.ensAddress = ensAddress
      fs.writeFileSync(path.join(__dirname, 'environment.json'), JSON.stringify(environment, null, 2))
    })
  } else {
    console.log(`ENS already deployed to ${environment.ensAddress}`)
  }
}

deploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
