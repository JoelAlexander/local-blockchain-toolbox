require("@nomiclabs/hardhat-ethers")
const ethJsUtil = require('ethereumjs-util')
const fs = require('fs')
const path = require('node:path')
const namehash = require('eth-ens-namehash')
const config = require('./hardhat.config.json')

async function sendEth(hre, amount, address) {
  return waitForConfirmation((overrides) => {
    return hre.localBlockchain.signer.sendTransaction({
      to: address,
      value: amount,
      gasPrice: overrides.gasPrice
    })
  })
}

async function getPublicResolver(hre) {
  const publicResolverAddress = await hre.localBlockchain.provider.resolveName('resolver')
  const PublicResolver = await hre.ethers.getContractFactory(
    "@ensdomains/ens-contracts/artifacts/contracts/resolvers/PublicResolver.sol:PublicResolver"
  )
  return PublicResolver.attach(publicResolverAddress).then((resolver) => {
    return resolver.connect(hre.localBlockchain.signer)
  })
}

// Need to setup ENS like this
// -  bytes32 public constant RESOLVER_LABEL = keccak256('resolver');
// -  bytes32 public constant REVERSE_REGISTRAR_LABEL = keccak256('reverse');
// -  bytes32 public constant ADDR_LABEL = keccak256('addr');
// -
// -  ENSRegistry public ens;
// -
// -  function namehash(bytes32 node, bytes32 label) public pure returns (bytes32) {
// -    return keccak256(abi.encodePacked(node, label));
// -  }
// -
// -  function topLevelNode(bytes32 label) public pure returns (bytes32) {
// -    return namehash(bytes32(0), label);
// -  }
// -    ens = new ENSRegistry();
// -
// -    bytes32 resolverNode = topLevelNode(RESOLVER_LABEL);
// -    PublicResolver publicResolver = new PublicResolver(ens, INameWrapper(address(0)));
// -    ens.setSubnodeOwner(bytes32(0), RESOLVER_LABEL, address(this));
// -    ens.setResolver(resolverNode, address(publicResolver));
// -    publicResolver.setAddr(resolverNode, address(publicResolver));
// -
// -    bytes32 reverseNode = topLevelNode(REVERSE_REGISTRAR_LABEL);
// -    bytes32 reverseAddressNode = namehash(reverseNode, ADDR_LABEL);
// -    ReverseRegistrar reverseRegistrar = new ReverseRegistrar(ens, NameResolver(address(publicResolver)));
// -    ens.setSubnodeOwner(bytes32(0), REVERSE_REGISTRAR_LABEL, address(this));
// -    ens.setSubnodeOwner(reverseNode, ADDR_LABEL, address(this));
// -    ens.setResolver(reverseAddressNode, address(publicResolver));
// -    publicResolver.setAddr(reverseAddressNode, address(reverseRegistrar));
// -    ens.setSubnodeOwner(reverseNode, ADDR_LABEL, address(reverseRegistrar));
// -
// -    // Give the caller control over the rest of the namespace.
// -    ens.setOwner(bytes32(0), msg.sender);

async function getEnsRegistry(hre) {
  const ENSRegistry = await hre.ethers.getContractFactory(
    "@ensdomains/ens-contracts/artifacts/contracts/registry/ENSRegistry.sol:ENSRegistry"
  )
  return ENSRegistry.attach(hre.localBlockchain.provider.network.ensAddress).then((registry) => {
    return registry.connect(hre.localBlockchain.signer)
  })
}

async function setPublicResolverAddr(hre, node, address) {
  const publicResolver = await getPublicResolver(hre)
  return waitForConfirmation((overrides) => {
    return publicResolver['setAddr(bytes32,address)'](node, address, overrides)
  })
}

async function setPublicResolver(hre, node) {
  const ensRegistry = await getEnsRegistry(hre)
  const publicResolver = await getPublicResolver(hre)
  return waitForConfirmation((overrides) => {
    return ensRegistry.setResolver(node, publicResolver.address, overrides)
  })
}

async function setSubnodeOwner(hre, node, label, owner) {
  const ensRegistry = await getEnsRegistry(hre)
  return waitForConfirmation((overrides) => {
    return ensRegistry.setSubnodeOwner(node, label, owner, overrides)
  })
}

async function claimSubnode(hre, node, label) {
  return setSubnodeOwner(hre, node, label, signer.address)
}

async function claimSubnodeAndSetAddr(node, label, subnode, addr) {
  return claimSubnode(node, label).then((receipt) => {
    console.log(`Setting resolver to the public resolver`)
    return setPublicResolver(subnode).then((receipt) => {
      console.log(`Setting address to ${addr}`)
      return setPublicResolverAddr(subnode, addr)
    })
  })
}

function leafLabelAndNode(hre, name) {
  const names = name.split('.')
  if (names.lenth === 0) {
    throw "Name must not be empty"
  }
  const leaf = names[0]
  const label = hre.ethers.utils.id(leaf)
  const nodeString = names.length === 1 ? '' : names.slice(1, names.length).join('.')
  const node = namehash.hash(nodeString)
  return [label, node]
}

async function createFifsTldNamespace(hre, tld) {
  const ensRegistry = await getEnsRegistry()
  const publicResolver = await getPublicResolver()
  const registrarName = `registrar.${tld}`
  const [tldLabel, rootNode] = leafLabelAndNode(hre, tld)
  const [registrarLabel, tldNode] = leafLabelAndNode(hre, registrarName)
  const registrarNode = namehash.hash(registrarName)
  console.log(`Deploying new FIFSRegistrar`)
  return deployContract(hre, "FIFSRegistrar", ensRegistry.address, tldNode).then((contract) => {
    console.log(`Claiming .${tld}`)
    return claimSubnode(hre, rootNode, tldLabel).then((receipt) => {
      console.log(`Claiming registrar.${tld}`)
      return claimSubnode(hre, tldNode, registrarLabel).then((receipt) => {
        console.log(`Setting resolver for registrar.${tld} to the public resolver`)
        return setPublicResolver(hre, registrarNode).then((receipt) => {
          console.log(`Setting address for registrar.${tld} to FIFSRegistrar at ${contract.address}`)
          return setPublicResolverAddr(hre, registrarNode, contract.address).then((receipt) => {
            console.log(`Changing owner of .${tld} to FIFSRegistrar at ${contract.address}`)
            return setSubnodeOwner(hre, rootNode, tldLabel, contract.address).then((receipt) => {
              console.log(`FIFSRegistrar 'registrar.${tld}' now owns .${tld} namespace`)
            })
          })
        })
      })
    })
  })
}

function getDeployedContractAddress(address, nonce) {
  return ethJsUtil.bufferToHex(
    ethJsUtil.generateAddress(
      ethJsUtil.toBuffer(address),
      ethJsUtil.toBuffer(nonce)))
}

async function makeGenesis(taskArguments) {
  const path = require('node:path')
  const fs = require('fs');

  const chainId = parseInt(taskArguments.chainId)
  const sealerAddress = taskArguments.sealerAddress.replace("0x", "")
  const genesisFilePath =  path.join(taskArguments.chainDir, 'genesis.json')
  const configurationFilePath = path.join(taskArguments.chainDir, 'config.json')

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

  const ensAddress = getDeployedContractAddress(creatorWallet.address, 0)
  const creatorBalance = "1000000000000000000"
  const faucetAlloc = "1000000000000000000000000"
  genesis.alloc[creatorWallet.address] = {
    "balance": creatorBalance
  }

  genesis.alloc[getDeployedContractAddress(creatorWallet.address, 1)] = {
    "balance": faucetAlloc
  }

  const configuration = {
    ens: ensAddress,
    creator: {
      address: creatorWallet.address,
      privateKey: creatorWallet.privateKey
    }
  }

  fs.writeFileSync(configurationFilePath, JSON.stringify(configuration, null, 2))
  fs.writeFileSync(genesisFilePath, JSON.stringify(genesis, null, 2))

  return Promise.resolve(genesis)
}

async function deployGenesis(hre, chainPath) {

  const ensAddress = hre.localBlockchain.provider.network.ensAddress
  const provider = hre.localBlockchain.provider
  const ensDeployed = await provider.getCode(ensAddress)
  // Check to see if ens is deployed and if subsequent genesis contracts are deployed.
  if (ensDeployed) {
    console.error(`Genesis contracts already deployed.`)
    return Promise.resolve()
  }

  const signer = hre.localBlockchain.signer
  const transactionCount = await signer.getTransactionCount()
  if (transactionCount !== 0) {
    console.error(`Faucet deployment should be transaction #0 for the creator account`)
    return Promise.resolve()
  }
  
  const faucetAddress = await deployContract('Faucet')

  const [faucetLabel, rootNode] = leafLabelAndNode(hre, 'faucet')
  const faucetNode = hash('faucet')
  await deployContract('ENSDeployment')

  console.log(`Claiming faucet and setting address to ${faucetAddress}`)
  return await claimSubnodeAndSetAddr(publicNode, faucetLabel, faucetNode, faucetAddress)
}

function configureModule(taskArguments) {
  const modulePath = taskArguments.modulePath
  const manifestPath = path.join(modulePath, 'manifest.json')
  const manifest = require(manifestPath)

  const configuration = {
    chainId: taskArguments.chainId,
    url: taskArguments.url,
    ens: taskArguments.ens
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

async function deployModule(taskArguments, hre) {
  const provider = hre.localBlockchain.provider
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
        await createFifsTldNamespace(key)
      } else {
        return Promise.reject(`unsupported registrar type ${value} for namepspace ${key}`)
      }
    }
  }

  if (manifest.deploy) {

    const [nameLabel, rootNode] = leafLabelAndNode(manifest.name)
    console.log(`Claiming .${manifest.name}`)
    await claimSubnode(rootNode, nameLabel).then((receipt) => {
      console.log(`Deploying module contracts`)
      const deployContractKeys = Object.keys(manifest.deploy)
      const deployContractPromise = (key) => {
        const value = manifest.deploy[key]
        console.log(`Deploying contract ${value} to ${key}`)
        return deployModuleContract(hre.localBlockchain.signer, modulePath, value).then((contract) => {
          const contractName = `${key}.${manifest.name}`
          console.log(`Claiming ${contractName} and setting address to ${contract.address}`)
          const [label, node] = leafLabelAndNode(`${key}.${manifest.name}`)
          const contractNode = hash(`${key}.${manifest.name}`)
          return claimSubnodeAndSetAddr(node, label, contractNode, contract.address)
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

task(
  "checkBalance",
  "Checks the balance of the creator account",
  async function (taskArguments, hre, runSuper) {
    const signer = hre.localBlockchain.signer
    return signer.getBalance().then((balance) => {
      console.log(`${signer.address}: ${balance}`)
    })
  }
)

task(
  "resolveName",
  "Resolves the name on ENS",
  async function (taskArguments, hre, runSuper) {
    const provider = hre.localBlockchain.provider
    return provider.resolveName(taskArguments.name).then((address) => {
      console.log(`${taskArguments.name}: ${address}`)
    })
  }
).addParam("name", "The name to resolve")

task(
  "makeGenesis",
  "Makes the genesis file for the local blockchain",
  async function (taskArguments, hre, runSuper) {
    return makeGenesis(taskArguments)
  }
).addParam("chainId", "The chainId of the blockchain")
.addParam("sealerAddress", "The public key of the intial sealer account")
.addParam("chainDir", "The path to the chain directory")

task(
  "deployGenesis",
  "Deploys the first contracts onto a fresh blockchain.",
  async function (taskArguments, hre, runSuper) {
    return deployGenesis(hre, taskArguments.chainDir)
  }
)
.addParam("chainDir", "The path to the chain directory")

task(
  "configureModule",
  "Writes a blockchain configuration file into a module directory, preparing it to be built.",
  async function (taskArguments, hre, runSuper) {
    return configureModule(taskArguments)
  })
.addParam("modulePath", "The path to the module")
.addParam("chainId", "The chainId of the blockchain")
.addParam("url", "An rpc url for the blockchain")
.addParam("ens", "The ens address for the blockchain")

task(
  "deployModule",
  "Checks a module for expected contracts and deploy its contracts to the blockchain.",
  async function (taskArguments, hre, runSuper) {
    return deployModule(taskArguments, hre)
  }
).addParam("modulePath", "The path to the module")

task(
  "sendEth",
  "Sends ether from the creator account to the specified address",
  async function (taskArguments, hre, runSuper) {
    return sendEth(taskArguments.amount, taskArguments.address)
  }
)
.addParam("amount", "The amount in eth")
.addParam("address", "The receipient address")

// Local blockchain harhat plugin
async function checkGasPrice() {
  return this.ethers.provider.getGasPrice().then((gasPrice) => {
    // Overpay 40% TODO: remove
    return gasPrice.add(gasPrice.div(40))
  })
}

async function deployContract(contractName, ...args) {
  const contractFactory = await this.ethers.getContractFactory(contractName)
  const gasPrice = await this.checkGasPrice()
  const contract = await contractFactory.deploy(...args, { gasPrice: gasPrice })
  console.log(`${contractName} deploying to: ${contract.address}`)
  return contract.deployTransaction.wait().then(() => {
    console.log(`${contractName} deployment confirmed`)
    return contract
  })
}

async function deployModuleContract(signer, modulePath, contractName, ...args) {
  const contractData = require(path.join(modulePath, "artifacts", "contracts", `${contractName}.sol`, `${contractName}.json`))
  const contractFactory = new ethers.ContractFactory(contractData.abi, contractData.bytecode, signer)
  const gasPrice = await this.checkGasPrice()
  const contract = await contractFactory.deploy(...args, { gasPrice: gasPrice })
  console.log(`${contractName} deploying to: ${contract.address}`)
  return contract.deployTransaction.wait().then(() => {
    console.log(`${contractName} deployment confirmed`)
    return contract
  })
}

async function deployContract(contractName, ...args) {
  const contractFactory = await this.ethers.getContractFactory(contractName)
  const gasPrice = await this.checkGasPrice()
  const contract = await contractFactory.deploy(...args, { gasPrice: gasPrice })
  console.log(`${contractName} deploying to: ${contract.address}`)
  return contract.deployTransaction.wait().then(() => {
    console.log(`${contractName} deployment confirmed`)
    return contract
  })
}

async function waitForConfirmation(transactionFactory) {
  const gasPrice = await this.checkGasPrice()

  return transactionFactory({ gasPrice: gasPrice }).then((response) => {
    return response.wait().then((receipt) => {
      return receipt
    }, (err) => {
      console.log(err)
    })
  }, (err) => {
    console.log(err)
  })
}

// extendEnvironment((hre) => {
//   if (!hre.config.chain) {
//     console.log(`No chain configured`)
//     return
//   }

//   const genesis = require(path.join(__dirname, 'chains', `${hre.config.chain.name}/genesis.json`))
//   const chainConfig = require(path.join(__dirname, 'chains', `${hre.config.chain.name}/config.json`))

//   hre.config.network[hre.config.chain.name] = {
//     chainId: genesis.config.chainId,
//     url: hre.config.chain.url,
//     accounts: [ chainConfig.creator.privateKey ]
//   }
//   hre.defaultNetwork = hre.config.chain.name
// })


extendEnvironment((hre) => {

  const chainConfig = require(path.join(__dirname, 'chains', `${hre.config.defaultNetwork}/config.json`))
  // hre.ethers.provider = new hre.ethers.providers.JsonRpcProvider({
  //   url: hre.ethers.provider.url
  // }, {
  //   ...hre.ethers.provider.network,
  //   ensAddress: chainConfig.ens
  // })
})

module.exports = config;
