const path = require('node:path')
const fs = require('fs')
const environment = require('./../environment.json')

const args = process.argv.slice(2)
const modulePath = args[0]

const manifest = require(path.join(modulePath, 'manifest.json'))

const configuration = {
  chainId: environment.chainId,
  blockchainUrl: environment.blockchainUrl,
  ensAddress: environment.ensAddress
}

const handleConfigurationEntry = (key) => {
  const value = manifest.configure[key]
  if ( === "random-private-key") {
    configuration[key] = ethers.Wallet.createRandom().privateKey
  } else {
    console.error(`Unsupported config: ${value}`)
  }
}

if (manifest.configure) {
  manifest.configure.keys().forEach((item, i) => {
    handleConfigurationEntry(item)
  });
}

fs.writeFileSync(path.join(modulePath, "blockchain.config"), JSON.stringify(configuration, null, 2))
