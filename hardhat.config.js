require("@nomiclabs/hardhat-ethers")
const ethJsUtil = require('ethereumjs-util')
const fs = require('fs')
const path = require('node:path')
const namehash = require('eth-ens-namehash')
const config = require('./hardhat.config.json')
const ethersUtils = require('ethers-utils')
const { types } = require("hardhat/config")

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
// -

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


// async function getEnsRegistry(hre) {

//   return ENSRegistry.attach(hre.localBlockchain.provider.network.ensAddress).then((registry) => {
//     return registry.connect(hre.localBlockchain.signer)
//   })
// }

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

function labelAndNode(name) {
  const names = name.split('.')
  if (names.length === 0) {
    throw "Name must not be empty"
  }
  const leaf = names[0]
  const label = ethersUtils.id(leaf)
  const nodeString = names.slice(1, names.length).join('.')
  const node = namehash.hash(nodeString)
  return [label, node]
}

async function createFifsTldNamespace(hre, tld) {
  const ensRegistry = await getEnsRegistry()
  const publicResolver = await getPublicResolver()
  const registrarName = `registrar.${tld}`
  const [tldLabel, rootNode] = labelAndNode(tld)
  const [registrarLabel, tldNode] = labelAndNode(registrarName)
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

async function makeGenesis(taskArguments) {
  const chainId = parseInt(taskArguments.chainId)
  const sealerAddress = taskArguments.sealerAddress.replace("0x", "")

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

  genesis.alloc[creatorWallet.address] = {
    // One million and one ETH
    "balance": "1000001000000000000000000"
  }

  const config = {
    creator: {
      address: creatorWallet.address,
      privateKey: creatorWallet.privateKey
    }
  }

  console.log(JSON.stringify({
    genesis: genesis,
    config: config
  }, null, 2))

  return Promise.resolve()
}

task(
  "makeGenesis",
  "Makes the genesis file for the local blockchain",
  async function (taskArguments, hre, runSuper) {
    return makeGenesis(taskArguments)
  }
).addParam("chainId", "The chainId of the blockchain")
.addParam("sealerAddress", "The public key of the intial sealer account")


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
  return claimSubnodeAndSetAddr(publicNode, faucetLabel, faucetNode, faucetAddress)
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
  "getGasPrice",
  "Gets the current gas price",
  async function (taskArguments, hre, runSuper) {
    const provider = await hre.run("getEnsProvider")
    return provider.getGasPrice()
  }
)

task(
  "checkBalance",
  "Checks the balance of the creator account",
  async function (taskArguments, hre, runSuper) {
    const provider = await hre.run("getEnsProvider")
    const signer = await hre.run("getEnsSigner")
    const address = taskArguments.address ? taskArguments.address : signer.address
    return provider.getBalance(address).then((balance) => {
      console.log(`${address}: ${balance}`)
    })
  }
).addOptionalPositionalParam('address', 'Address to check balance of')

task(
  "executeTransaction",
  "Executes the transaction",
  async function (taskArguments, hre, runSuper) {
    const gasPrice = await hre.run("getGasPrice")
      .then((gasPrice) => {
        // Overpay 40%
        return gasPrice.add(gasPrice.div(40))
      })
    const signer = await hre.run("getEnsSigner")
    const unsignedTransaction = taskArguments.transaction
    unsignedTransaction.gasPrice = gasPrice
    return signer.sendTransaction(taskArguments.transaction)
      .then((response) => {
        return response.wait().then((receipt) => {
          return receipt
        }, (err) => {
          console.log(err)
        })
      }, (err) => {
        console.log(err)
      })
  }
).addParam('transaction', 'Transaction to send', undefined, types.json)

task(
  "getEnsRegistry",
  "Gets the ENS registry for the active chain",
  async function (taskArguments, hre, runSuper) {
    if (!hre.network.config.ensAddress) {
      return Promise.resolve(null)
    }

    return hre.run(
      "getDeployedContract",
      { contractName: "@ensdomains/ens-contracts/artifacts/contracts/registry/ENSRegistry.sol:ENSRegistry",
        address: hre.network.config.ensAddress }
    )
  }
)

task(
  "getEnsProvider",
  "Gets an ENS enabled provider for the active chain",
  async function (taskArguments, hre, runSuper) {

    return hre.run(
      "getEnsRegistry"
    ).then((ensRegistry) => {
      const providerConfig = {
        name: hre.network.name,
        chainId: hre.network.config.chainId
      }
      if (ensRegistry) {
        providerConfig.ensAddress = ensRegistry.address
      }
      const provider = new hre.ethers.providers.JsonRpcProvider({
        url: hre.network.config.url
      }, providerConfig)
      return provider
    })
  }
)

task(
  "getEnsSigner",
  "Gets an ENS enabled signer for the active chain",
  async function (taskArguments, hre, runSuper) {

    if (!hre.network.config.accounts || hre.network.config.accounts.length < 1) {
      console.log(`No account found for chain ${hre.network.name}`)
      return Promise.resolve()
    }

    return hre.run(
      "getEnsProvider"
    ).then((ensProvider) => {
      return new hre.ethers.Wallet(hre.network.config.accounts[0], ensProvider)
    })
  }
)

task(
  "getContractFactory",
  "Gets a contract factory",
  async function (taskArguments, hre, runSuper) {
    return hre.ethers.getContractFactory(taskArguments.contractName)
  }
)
.addParam("contractName", "The name or fully qualified name of the contract")

task(
  "getDeployedContract",
  "Gets a contract factory",
  async function (taskArguments, hre, runSuper) {
    return hre.run(
      "getContractFactory",
      { contractName: taskArguments.contractName }).then((contractFactory) => {
        return contractFactory.attach(taskArguments.address)
      })
  }
)
.addParam("contractName", "The name or fully qualified name of the contract")
.addParam("address", "The address of the deployed contract")

task(
  "getPublicResolver",
  "Gets the public ENS resolver contract",
  async function (taskArguments, hre, runSuper) {
    const signer = await hre.run("getEnsSigner")
    const resolverAddress = await hre.run("resolveName", { name: 'resolver' })
    const returnVal = resolverAddress === null ? null :
      await hre.run("getDeployedContract", {
        contractName: "@ensdomains/ens-contracts/artifacts/contracts/resolvers/PublicResolver.sol:PublicResolver",
        address: resolverAddress
      }).then((contract) => { contract })
    console.log(returnVal)
    return returnVal
  }
)

task(
  "resolveName",
  "Resolves a name on the network's ENS instance",
  async function (taskArguments, hre, runSuper) {
    const provider = await hre.run("getEnsProvider")
    return provider.resolveName(taskArguments.name).then(console.log)
  }
).addParam("name", "Name to resolve")

task(
  "deployContract",
  "Deploys a contract",
  async function (taskArguments, hre, runSuper) {
    const args = taskArguments.args ? taskArguments.args : []
    const contractName = taskArguments.contractName
    const gasPrice = await hre.run("getGasPrice")
    const contractFactory = await hre.run("getContractFactory", { contractName: contractName })
    const contract = await contractFactory.deploy(...args, { gasPrice: gasPrice })
    return contract.deployTransaction.wait().then(() => {
      return contract
    })
  }
).addParam("contractName", "The name or fully qualified name of the contract")
.addOptionalVariadicPositionalParam("args", "Additional contract constructor arguments")

task(
  "deployEnsRegistry",
  "Deploys an Ens registry.",
  async function (taskArguments, hre, runSuper) {

    const [resolverLabel,] = labelAndNode('resolver')
    const resolverNode = namehash.hash('resolver')
    const [reverseLabel,] = labelAndNode('reverse')
    const [addrLabel, reverseNode] = labelAndNode('addr.reverse')
    const reverseAddrNode = namehash.hash('addr.reverse')
    const [deployerLabel,] = labelAndNode('deployer')
    const deployerNode = namehash.hash('deployer')
    const publicResolverContractName = "@ensdomains/ens-contracts/artifacts/contracts/resolvers/PublicResolver.sol:PublicResolver"

    const exec = (pt) => {
      return pt.then((t) => {
        return hre.run("executeTransaction", { transaction: t})
      })
    }

    const deployedEnsRegistry = await hre.run("getEnsRegistry")
      .then((existingEnsRegistry) => {
        if (existingEnsRegistry) {
          return existingEnsRegistry
        } else {
          console.log(`Deploying ENS Registry`)
          return hre.run(
            "deployContract",
            { contractName: "@ensdomains/ens-contracts/artifacts/contracts/registry/ENSRegistry.sol:ENSRegistry"}
          ).then((newlyDeployedEnsRegistry) => {
            hre.network.config.ensAddress = newlyDeployedEnsRegistry.address
            return newlyDeployedEnsRegistry
          })
        }
      })
      
    const ensSigner = await hre.run("getEnsSigner")
    const ensRegistry = await Promise.resolve(deployedEnsRegistry)
      .then((deployedEnsRegistry) => {
        console.log(`Using ENSRegistry: ${deployedEnsRegistry.address}`)
        return deployedEnsRegistry.connect(ensSigner)
      })

    const resolver = await hre.run("getResolver")
      .then((existingResolver) => {
        if (existingResolver) {
          return hre.run('getDeployedContract', {
            contractName: publicResolverContractName,
            address: existingResolver.address })
        } else {
          console.log(`Deploying resolver`)
          return hre.run(
            "deployContract",
            { contractName: publicResolverContractName , args: [ ensRegistry.address ]})
            .then((deployedResolver) => {
              console.log(`Claiming name: resolver`)
              return hre.run(
                "claimSubnode",
                { name: 'resolver' })
              .then(() => {
                console.log(`Setting resolver of node 'resolver' to ${deployedResolver.address}`)
                return exec(ensRegistry.populateTransaction.setResolver(resolverNode, deployedResolver.address))
                .then(() => {
                  console.log(`Setting address of resolver to ${deployedResolver.address}`)
                  return exec(deployedResolver.populateTransaction['setAddr(bytes32,address)'](resolverNode, deployedResolver.address))
                  .then(() => {
                    return deployedResolver
                  })
                })
              }) 
            })
        }
      })
      .then((deployedResolver) => {
        console.log(`Using resolver: ${deployedResolver.address}`)
        return deployedResolver.connect(ensSigner)
      })

    const reverseRegistrar = await ensSigner.resolveName('addr.reverse')
      .then((existingReverseRegistrar) => {
        const reverseRegistrarContractName = '@ensdomains/ens-contracts/artifacts/contracts/registry/ReverseRegistrar.sol:ReverseRegistrar'
        if (existingReverseRegistrar) {
          return hre.run('getDeployedContract',
            { contractName: reverseRegistrarContractName,
              address: existingReverseRegistrar })
        } else {
          console.log(`Deploying reverse registrar`)
          return hre.run(
            'deployContract',
            { contractName: reverseRegistrarContractName, args: [ ensRegistry.address, resolver.address ]})
            .then((deployedReverseRegistrar) => {
              console.log(`Claiming name: reverse`)
              return hre.run('claimSubnode', { name: 'reverse' })
                .then(() => {
                  console.log(`Claiming name: addr.reverse`)
                  return hre.run('claimSubnode', { name: 'addr.reverse'})
                })
                .then(() => {
                  console.log(`Setting resolver of node 'addr.resolver' to ${resolver.address}`)
                  return exec(ensRegistry.populateTransaction.setResolver(reverseAddrNode, resolver.address))
                })
                .then(() => {
                  console.log(`Setting address of reverse registrar`)
                  return exec(resolver.populateTransaction['setAddr(bytes32,address)'](reverseAddrNode, deployedReverseRegistrar.address))
                })
                .then(() => {
                  console.log(`Setting ownership of addr.reverse to reverse registrar`)
                  return hre.run('setSubnodeOwner', { name: 'addr.reverse', owner: deployedReverseRegistrar.address })
                })
                .then(() => { return deployedReverseRegistrar })
            })
        }
      })
      .then((deployedReverseRegistrar) => {
        console.log(`Using reverse registrar: ${deployedReverseRegistrar.address}`)
        return deployedReverseRegistrar.connect(ensSigner)
      })

    console.log(`Claiming name: deployer`)
    await hre.run('claimSubnode', { name: 'deployer' })

    console.log(`Setting address for deployer to: ${ensSigner.address}`)
    await exec(resolver.populateTransaction['setAddr(bytes32,address)'](deployerNode, ensSigner.address))

    console.log(`Setting name as deployer in reverse registrar`)
    await exec(reverseRegistrar.populateTransaction.setName('deployer'))

    console.log(`Setting resolver of deployer to public resolver`)
    await exec(ensRegistry.populateTransaction.setResolver(deployerNode, resolver.address))

    const ensSigner2 = await hre.run('getEnsSigner')
    const resolvedDeployer = await ensSigner2.resolveName('deployer')
    console.log(`Resolved deployer to: ${resolvedDeployer}`)
  }
)

task(
  "setSubnodeOwner",
  "Sets the owner of an ENS subnode",
  async function (taskArguments, hre, runSuper) {
    const signer = await hre.run("getEnsSigner")
    const ensRegistry = await hre.run("getEnsRegistry").then((registry) => registry.connect(signer))
    const gasPrice = await hre.run("getGasPrice")
    const [label, node] = labelAndNode(taskArguments.name)
    const transaction = await ensRegistry.populateTransaction.setSubnodeOwner(node, label, taskArguments.owner)
    return hre.run("executeTransaction", { transaction: transaction })
  }
).addParam("name", "The name of the node")
.addParam("owner", "The address of the new owner")

task(
  "getResolver",
  "Gets the resolver",
  async function (taskArguments, hre, runSuper) {
    const name = taskArguments.name ? taskArguments.name : 'resolver'
    const provider = await hre.run("getEnsProvider")
    return provider.getResolver(name)
  }
).addOptionalParam("name", "The name of the node to get the resolver of.  Defaults to public resolver: 'resolver'")

task(
  "setResolver",
  "Sets the resolver of an ENS subnode",
  async function (taskArguments, hre, runSuper) {
    const signer = await hre.run("getEnsSigner")
    const ensRegistry = await hre.run("getResolver").then((registry) => registry.connect(signer))
    const gasPrice = await hre.run("getGasPrice")
    const [label, node] = labelAndNode(taskArguments.name)
    const transaction = ensRegistry.setResolver(node, taskArguments.resolver, { gasPrice: gasPrice })
    return waitForConfirmation(transaction)
  }
).addParam("name", "The name of the node")
.addParam("resolver", "The address of the resolver")

task(
  "getOwner",
  "Gets the owner of an ENS node",
  async function (taskArguments, hre, runSuper) {
    const ensRegistry = await hre.run("getEnsRegistry")
    return ensRegistry.owner(namehash.hash(taskArguments.name)).then(console.log)
  }
).addParam("name", "ENS name")

task(
  "claimSubnode",
  "Claims the ENS subnode",
  async function (taskArguments, hre, runSuper) {
    const signer = await hre.run("getEnsSigner")
    return hre.run("setSubnodeOwner", {
      name: taskArguments.name,
      owner: signer.address
    })
  }
).addParam("name", "The name of the node")

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
    const signer = await hre.run("getEnsSigner")
    const gasPrice = await hre.run("getGasPrice")
    const transaction = signer.sendTransaction({
        to: taskArguments.address,
        value: taskArguments.amount,
        gasPrice: gasPrice
    })
    return waitForConfirmation(transaction)
  }
)
.addParam("amount", "The amount in eth")
.addParam("address", "The receipient address")

task(
  "foo",
  "bar",
  async function (taskArguments, hre, runSuper) {
    return hre.run("getOwner", { name: taskArguments.name }).then(console.log)
  }
).addParam("name", "The name of the node")

// Local blockchain harhat plugin
async function deployModuleContract(hre, modulePath, contractName, ...args) {
  const signer = await hre.ethers.getSigner()
  const contractData = require(path.join(modulePath, "artifacts", "contracts", `${contractName}.sol`, `${contractName}.json`))
  const contractFactory = new ethers.ContractFactory(contractData.abi, contractData.bytecode, signer)
  const gasPrice = await hre.run("getGasPrice")
  const contract = await contractFactory.deploy(...args, { gasPrice: gasPrice })
  console.log(`${contractName} deploying to: ${contract.address}`)
  return contract.deployTransaction.wait().then(() => {
    console.log(`${contractName} deployment confirmed`)
    return contract
  })
}

async function waitForConfirmation(transaction) {
  return transaction.then((response) => {
    return response.wait().then((receipt) => {
      return receipt
    }, (err) => {
      console.log(err)
    })
  }, (err) => {
    console.log(err)
  })
}

module.exports = config;
