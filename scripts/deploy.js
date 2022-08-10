const path = require('node:path')
const fs = require('fs')
const ethJsUtil = require('ethereumjs-util')
const environment = require('./../environment.json')
const utils = require('./utils.js')
const ensUtils = require('./ensUtils.js')

async function makeGenesis(taskArguments) {
  const path = require('node:path')
  const fs = require('fs');

  const chainId = parseInt(taskArguments.chainId)
  const sealerAddress = taskArguments.sealerAddress.replace("0x", "")
  const genesisFilePath = taskArguments.genesisFile
  const creatorFilePath = taskArguments.creatorFile

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

  fs.writeFileSync(path.join(process.cwd(), creatorFilePath), JSON.stringify(creator, null, 2))
  fs.writeFileSync(path.join(process.cwd(), genesisFilePath), JSON.stringify(genesis, null, 2))

  return Promise.resolve()
}

async function deployGenesis() {
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

  const [publicLabel, rootNode] = ensUtils.leafLabelAndNode('public')
  const [faucetLabel, publicNode] = ensUtils.leafLabelAndNode('faucet.public')
  const faucetNode = ensUtils.hash('faucet.public')
  if (!environment.ensAddress) {
    await utils.deployContract('ENSDeployment').then((ensDeployment) => {
      return ensDeployment.ens()
    }).then((ensAddress) => {
      console.log(`Writing updated environment file`)
      environment.ensAddress = ensAddress
      fs.writeFileSync(path.join(__dirname, '..', 'environment.json'), JSON.stringify(environment, null, 2))
      console.log(`Claiming .public`)
      return ensUtils.claimSubnode(rootNode, publicLabel).then((receipt) => {
        console.log(`Claiming faucet.public and setting address to ${environment.faucetAddress}`)
        return ensUtils.claimSubnodeAndSetAddr(publicNode, faucetLabel, faucetNode, environment.faucetAddress)
      })
    })
  } else {
    console.log(`ENS already deployed to ${environment.ensAddress}`)
  }
}

function configureModule(taskArguments) {
  const modulePath = taskArguments.modulePath
  const manifestPath = path.join(modulePath, 'manifest.json')
  const manifest = require(manifestPath)

  const configuration = {
    chainId: environment.chainId,
    blockchainUrl: environment.blockchainUrl,
    ensAddress: environment.ensAddress
  }

  const handleConfigurationEntry = (key) => {
    const value = manifest.configure[key]
    if (value === "random-private-key") {
      console.log(`Handling ${key}, ${value}`)
      configuration[key] = ethers.Wallet.createRandom().privateKey
    } else {
      console.error(`Unsupported config: ${value}`)
    }
  }

  if (manifest.configure) {
    Object.keys(manifest.configure).forEach((item, i) => {
      handleConfigurationEntry(item)
    });
  }

  const configurationPath = path.join(modulePath, "configuration.json")
  console.log(`Writing configuration.json to ${configurationPath}`)
  fs.writeFileSync(configurationPath, JSON.stringify(configuration, null, 2))
  return Promise.resolve()
}

async function deployModule(taskArguments) {
  const provider = await ensUtils.getEnsProvider()
  const modulePath = taskArguments.modulePath
  const manifestPath = path.join(modulePath, 'manifest.json')
  const manifest = require(manifestPath)

  const makeEnsName = (name) => {
    return `${name}.${manifest.name}`
  }

  if (!manifest.name) {
    return Promise.reject(`name required in manifest`)
  }

  // TODO: Verify the expected abi against the deployed contract
  if (manifest.expect) {
    const hasAllExpected = await Promise.all(
      Object.keys(manifest.expect).map((key) => {
        return provider.resolveName(key).then((resolved) => {
          if (!resolved) {
            console.error(`${key} is not mapped to an address, but expected by ${manifest.name}`)
            return false
          }
          return true
        })
      })
    ).then((all) => {
      return all.reduce((prev, cur) => { return prev && cur }, true)
    })

    if (!hasAllExpected) {
      return Promise.reject(`missing expected contracts`)
    }
  }

  if (manifest.namespaces) {
    const keys = Object.keys(manifest.namespaces)
    for (var i = 0; i < keys.length; i++) {
      const key = keys[i]
      const value = manifest.namespaces[key]
      if (value === "FIFSRegistrar") {
        await ensUtils.createFifsTldNamespace(key)
      } else {
        return Promise.reject(`unsupported registrar type ${value} for namepspace ${key}`)
      }
    }
  }

  if (manifest.deploy) {

    const [nameLabel, rootNode] = ensUtils.leafLabelAndNode(manifest.name)
    console.log(`Claiming .${manifest.name}`)
    await ensUtils.claimSubnode(rootNode, nameLabel).then((receipt) => {
      console.log(`Deploying module contracts`)
      const deployContractKeys = Object.keys(manifest.deploy)
      const deployContractPromise = (key) => {
        const value = manifest.deploy[key]
        console.log(`Deploying contract ${value} to ${key}`)
        return utils.deployModuleContract(modulePath, value).then((contract) => {
          const contractName = `${key}.${manifest.name}`
          console.log(`Claiming ${contractName} and setting address to ${contract.address}`)
          const [label, node] = ensUtils.leafLabelAndNode(`${key}.${manifest.name}`)
          const contractNode = ensUtils.hash(`${key}.${manifest.name}`)
          return ensUtils.claimSubnodeAndSetAddr(node, label, contractNode, contract.address)
        })
      }
      return deployContractKeys.reduce(
        (prev, nextKey) => { return prev.then(() => { return deployContractPromise(nextKey) })},
        Promise.resolve())
    })
  }

  console.log(`Module ${manifest.name} deployed`)
  return Promise.resolve()
}

module.exports.makeGenesis = makeGenesis
module.exports.deployGenesis = deployGenesis
module.exports.configureModule = configureModule
module.exports.deployModule = deployModule
