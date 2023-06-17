require("@nomiclabs/hardhat-ethers")
const ethJsUtil = require('ethereumjs-util')
const fs = require('fs')
const path = require('node:path')
const namehash = require('eth-ens-namehash')
const config = require('./hardhat.config.json')
const ethersUtils = require('ethers-utils')
const { types } = require("hardhat/config")

task(
  "makeGenesis",
  "Makes the genesis file for the local blockchain",
  async function (taskArguments, hre, runSuper) {
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
).addParam("chainId", "The chainId of the blockchain")
.addParam("sealerAddress", "The public key of the intial sealer account")

task(
  "createFundedAccount",
  "Creates and funds a account",
  async function (taskArguments, hre, runSuper) {
    const wallet = ethers.Wallet.createRandom()
    console.log(`Funding new account ${wallet.address} with 1 ETH: ${wallet.privateKey}`)
    return hre.run('sendEth', { to: wallet.address, value: "1000000000000000000" })
  }
);

task(
  "configureModule",
  "Configures a local blockchain module for the current chain based on its manifest",
  async function (taskArguments, hre, runSuper) {
    const modulePath = taskArguments.modulePath
    const manifestPath = path.join(modulePath, 'manifest.json')
    const manifest = require(manifestPath)

    const configuration = {
      chainId: hre.network.config.chainId,
      url: hre.network.config.url,
      ens: hre.network.config.ensAddress
    }

    const handleConfigurationEntry = (key) => {
      const value = manifest.resources[key]
      if (key === "houseWallet") {
        console.log(`Handling ${key}`)
        const wallet = ethers.Wallet.createRandom()
        configuration[key] = wallet.privateKey
        console.log(`Funding new public account ${wallet.address} with 0.01 ETH`)
        return hre.run('sendEth', { to: wallet.address, value: "10000000000000000" })
      } else {
        console.error(`Unsupported config: ${key}`)
      }
    }

    if (manifest.resources) {
      const configurationKeys = Object.keys(manifest.resources)
      for (var i = 0; i < configurationKeys.length; i++) {
        await handleConfigurationEntry(configurationKeys[i])
      }
    }

    console.log(JSON.stringify(configuration))
    return Promise.resolve(JSON.stringify(configuration))
  }
)
.addParam('modulePath', 'The absolute path to the module.')

task(
  "deployModule",
  "Deploys the module according to the manifest",
  async function (taskArguments, hre, runSuper) {
    const ensRegistry = await hre.run("getEnsRegistry");
    const publicResolver = await hre.run("getPublicResolver");
    const modulePath = taskArguments.modulePath
    const manifestPath = path.join(modulePath, 'manifest.json')
    const manifest = require(manifestPath)
    const reservedKeys = { 'registrar' : true }

    const deployedContracts = {
      'ens': ensRegistry.address,
      'resolver': publicResolver.address
    };
    const deployContracts = taskArguments.deploy || [];

    const makeEnsName = (name) => {
      return `${name}.${manifest.name}`
    }

    if(manifest.deploy && (manifest.deploy.registrar || manifest.deploy.ens || manifest.deploy.resolver)){
        return Promise.reject(`'registrar, ens, and resolver' are reserved keys and cannot be used in the deploy list.`);
    }

    if (manifest.namespace && manifest.namespace.type) {
      if (manifest.namespace.type === "FIFSRegistrar") {
        // Adding the FIFSRegistrar into the deploy list.
        const ensRegistry = await hre.run('getEnsRegistry')
        const node = namehash.hash(manifest.name)
        manifest.deploy["registrar"] = {
            "source": "@ensdomains/ens-contracts/artifacts/contracts/registry/FIFSRegistrar.sol:FIFSRegistrar",
            "args": [ensRegistry.address, node]
        };
      } else {
        return Promise.reject(`unsupported registrar type ${namespace.type} for namespace ${namespaceKey}`);
      }
    }

    if (manifest.deploy) {
      console.log(`Claiming .${manifest.name}`);
      await hre.run('claimSubnode', { name: manifest.name }).then(async () => {
        console.log(`Deploying module contracts`);
        const deployContractKeys = Object.keys(manifest.deploy);
        
        const deployContractPromise = async (key) => {
          const contractConfig = manifest.deploy[key];
          const ensName = makeEnsName(key);

          if (deployContracts.length > 0 && !deployContracts.includes(key)) {
            console.log(`Skipping deployment for contract ${contractConfig.source}`);
            return;
          }

          const existingContractAddress = await hre.run("getAddress", { name: ensName });
          if (existingContractAddress && !deployContracts.includes(key)) {
            console.log(`Contract ${contractConfig.source} already deployed at ${existingContractAddress}`);
            deployedContracts[key] = existingContractAddress;
            return;
          }

          console.log(`Deploying contract ${contractConfig.source} to ${key}`);
          const contract = await hre.run('deployContractToSubnode', {
            modulePath: reservedKeys[key] ? undefined : taskArguments.modulePath,
            contractName: contractConfig.source,
            name: `${key}.${manifest.name}`,
            args: contractConfig.args });

          deployedContracts[key] = contract.address;

          if (contractConfig.ownSubdomain) {
            console.log(`Transfering ownership of ${key}.${manifest.name} to ${contract.address}`)
            await hre.run('setSubnodeOwner', { name: `${key}.${manifest.name}`, owner: contract.address })
          }
        };

        await deployContractKeys.reduce(
          (prev, nextKey) => prev.then(() => deployContractPromise(nextKey)),
          Promise.resolve(),
        );

        // Set ownership of the namespace to the registrar
        if (manifest.namespace && manifest.namespace.type && manifest.namespace.type === "FIFSRegistrar") {
          const registrarName = `registrar.${manifest.name}`
          console.log(`Setting '${registrarName}' as the owner of .${manifest.name} namespace`)
          await hre.run('setSubnodeOwner', { name: manifest.name, owner: registrarName });
        }
      });
    }

    console.log(`Module ${manifest.name} deployed`);
    return Promise.resolve();
  }
).addParam('modulePath', 'The absolute path to the module.')
.addOptionalVariadicPositionalParam("deploy", "List of contracts to be deployed");

task(
  "getGasPrice",
  "Gets the current gas price",
  async function (taskArguments, hre, runSuper) {
    const provider = await hre.run("getEnsProvider")
    return provider.getGasPrice()
  }
)

task(
  "getBalance",
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
    const provider = await hre.run("getEnsProvider")
    const resolverAddress = await provider.resolveName('resolver')
    return resolverAddress === null ? null :
      await hre.run("getDeployedContract", {
        contractName: "@ensdomains/ens-contracts/artifacts/contracts/resolvers/PublicResolver.sol:PublicResolver",
        address: resolverAddress
      })
  }
)

task(
  "getAddress",
  "Resolves a name on the network's ENS instance",
  async function (taskArguments, hre, runSuper) {
    const provider = await hre.run("getEnsProvider")
    const address = await provider.resolveName(taskArguments.name)
    console.log(`Resolved ${taskArguments.name} to ${address}`)
    return address
  }
).addParam("name", "Name to resolve")

task(
  "getModuleContractFactory",
  "Loads a contract from a module",
  async function (taskArguments, hre, runSuper) {
    const signer = await hre.run('getEnsSigner')
    const contractName = taskArguments.contractName
    const contractNameParts = contractName.split('/')
    const moduleContractPath = path.join(taskArguments.modulePath, "artifacts", "contracts", `${contractName}.sol`, `${contractName}.json`)
    const moduleDependencyContractPath = path.join(taskArguments.modulePath, "node_modules", contractNameParts[0] || '', contractNameParts[1] || '', "artifacts", "contracts", contractNameParts.slice(2, contractNameParts.length - 1).join('/'), `${contractNameParts[contractNameParts.length - 1]}.sol`, `${contractNameParts[contractNameParts.length - 1]}.json`)
    const contractData = fs.existsSync(moduleContractPath) ? require(moduleContractPath) : require(moduleDependencyContractPath)
    return new ethers.ContractFactory(contractData.abi, contractData.bytecode, signer)
  }
).addParam("modulePath", "The path to the module")
.addParam("contractName", "The contract name within the module")

task(
  "deployContract",
  "Deploys a contract from a module",
  async function (taskArguments, hre, runSuper) {
    const args = taskArguments.args ? taskArguments.args : []
    const contractFactory = taskArguments.modulePath ? 
      await hre.run("getModuleContractFactory", { modulePath: taskArguments.modulePath, contractName: taskArguments.contractName }) :
      await hre.run("getContractFactory", { contractName: taskArguments.contractName })
    const gasPrice = await hre.run("getGasPrice")
    const contract = await contractFactory.deploy(...args, { gasPrice: gasPrice })
    console.log(`${taskArguments.contractName} deploying to: ${contract.address}`)
    return contract.deployTransaction.wait().then(() => {
      console.log(`${taskArguments.contractName} deployment confirmed`)
      return contract
    })
  }
).addParam("contractName", "The contract name within the module")
.addOptionalParam("modulePath", "The path to the module")
.addOptionalVariadicPositionalParam("args", "Additional contract constructor arguments")

task(
  "getDeployedModuleContract",
  "Gets a contract factory",
  async function (taskArguments, hre, runSuper) {
    return hre.run(
      "getModuleContractFactory",
      { modulePath: taskArguments.modulePath, contractName: taskArguments.contractName, address: taskArguments.address }).then((contractFactory) => {
        return contractFactory.attach(taskArguments.address)
      }).then(console.log)
  }
).addParam("modulePath", "The path to the module")
.addParam("contractName", "The name or fully qualified name of the contract")
.addParam("address", "The address of the deployed contract")

task(
  "callDeployedModuleContract",
  "Call a deployed contract from a deployed module",
  async function (taskArguments, hre, runSuper) {
    const overrides = {}
    const args = taskArguments.args ? taskArguments.args : []
    if (taskArguments.value) {
      overrides.value = taskArguments.value
    }
    const contract = await hre.run("getDeployedModuleContract", { modulePath: taskArguments.modulePath, contractName: taskArguments.contractName, address: taskArguments.address })
    console.log(`Executing method: ${taskArguments.method} on ${taskArguments.contractName} at ${taskArguments.address} with a value of ${taskArguments.value}`)
    const transaction = await contract.populateTransaction[taskArguments.method](...args, overrides)
    return hre.run("executeTransaction", { transaction: transaction }).then(console.log)
  }
).addParam("modulePath", "The path to the module")
.addParam("contractName", "The name or fully qualified name of the contract")
.addParam("address", "The address of the deployed contract")
.addParam("method", "The method name to call")
.addOptionalParam("value", "The value to send in the contract")
.addOptionalVariadicPositionalParam("args", "Additional contract constructor arguments")

task(
  "deployEns",
  "Deploys an Ens registry.",
  async function (taskArguments, hre, runSuper) {

    const resolverNode = namehash.hash('resolver')
    const reverseAddrNode = namehash.hash('addr.reverse')
    const publicResolverContractName = "@ensdomains/ens-contracts/artifacts/contracts/resolvers/PublicResolver.sol:PublicResolver"

    const exec = (pt) => {
      return pt.then((t) => {
        return hre.run("executeTransaction", { transaction: t })
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
  }
)

task(
  "setSubnodeOwner",
  "Sets the owner of an ENS subnode",
  async function (taskArguments, hre, runSuper) {

    const labelAndNode = (name) => {
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

    const signer = await hre.run("getEnsSigner")
    const ensRegistry = await hre.run("getEnsRegistry").then((registry) => registry.connect(signer))
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
    const ensRegistry = await hre.run("getEnsRegistry").then((registry) => registry.connect(signer))
    const gasPrice = await hre.run("getGasPrice")
    const node = namehash.hash(taskArguments.name)
    const transaction = await ensRegistry.populateTransaction.setResolver(node, taskArguments.resolver, { gasPrice: gasPrice })
    return hre.run('executeTransaction', { transaction: transaction })
  }
).addParam("name", "The name of the node")
.addParam("resolver", "The address of the resolver")

task(
  "setPublicResolver",
  "Sets the owner of an ENS subnode",
  async function (taskArguments, hre, runSuper) {
    const ensRegistry = await hre.run("getEnsRegistry");
    const name = taskArguments.name;
    const node = namehash.hash(name);
    const publicResolver = await hre.run("getPublicResolver");
    const currentResolver = await ensRegistry.resolver(node);

    if (currentResolver === publicResolver.address) {
      console.log(`The public resolver for the node ${name} is already set`);
      return;
    }

    console.log(`Setting the public resolver for the node ${name}`);
    return hre.run("setResolver", { name: taskArguments.name, resolver: publicResolver.address });
  }
).addParam("name", "The name of the node");

task(
  "setPublicResolverAddress",
  "Sets the owner of an ENS subnode",
  async function (taskArguments, hre, runSuper) {
    const node = namehash.hash(taskArguments.name)
    const resolver = await hre.run("getPublicResolver")
    const transaction = await resolver.populateTransaction['setAddr(bytes32,address)'](node, taskArguments.address)
    return hre.run("executeTransaction", { transaction: transaction })
  }
).addParam("name", "The name of the node")
.addParam("address", "The address to set")

task(
  "setAddress",
  "Sets the address for the current resolver of an ENS node",
  async function (taskArguments, hre, runSuper) {
    const node = namehash.hash(taskArguments.name)
    const signer = await hre.run("getEnsSigner")
    const ensRegistry = await hre.run("getEnsRegistry");
    const currentResolverAddress = await ensRegistry.resolver(node);
    if (currentResolverAddress === ethers.constants.AddressZero) {
      throw new Error(`No resolver set for ENS node ${taskArguments.name}`);
    }

    const currentResolver = await hre.ethers.getContractAt(
      "@ensdomains/ens-contracts/artifacts/contracts/resolvers/Resolver.sol:Resolver",
      currentResolverAddress,
      signer)

    const currentAddress = await currentResolver['addr(bytes32)'](node);
    if (currentAddress.toLowerCase() === taskArguments.address.toLowerCase()) {
      console.log(`The address for the node ${taskArguments.name} is already set to the desired value`);
      return;
    }

    const transaction = await currentResolver.populateTransaction['setAddr(bytes32,address)'](node, taskArguments.address)
    return hre.run("executeTransaction", { transaction: transaction })
  }
).addParam("name", "The name of the node")
.addParam("address", "The address to set")

task(
  "getOwner",
  "Gets the owner of an ENS node",
  async function (taskArguments, hre, runSuper) {
    const ensRegistry = await hre.run("getEnsRegistry")
    const owner = await ensRegistry.owner(namehash.hash(taskArguments.name))
    console.log(`Owner of ${taskArguments.name} is ${owner}`)
    return owner
  }
).addOptionalParam("name", "ENS name")

task(
  "claimSubnode",
  "Claims the ENS subnode",
  async function (taskArguments, hre, runSuper) {
    const signer = await hre.run("getEnsSigner")
    const ensRegistry = await hre.run("getEnsRegistry")
    const name = taskArguments.name
    const node = namehash.hash(name)
    const currentOwner = await ensRegistry.owner(node)

    if (currentOwner === signer.address) {
      console.log(`Subnode ${name} is already owned by the current signer`)
      return
    }

    return hre.run("setSubnodeOwner", {
      name: name,
      owner: signer.address
    })
  }
).addParam("name", "The name of the node")

task(
  "claimSubnodeWithPublicResolver",
  "Claims the ENS subnode and sets the resolver to the public resolver",
  async function (taskArguments, hre, runSuper) {
    return hre.run("claimSubnode", { name: taskArguments.name })
      .then(() => hre.run("setPublicResolver", { name: taskArguments.name }));
  }
).addParam("name", "The name of the node")

task(
  "claimSubnodeWithAddress",
  "Claims the ENS subnode, sets the resolver to the public resolver, and sets the address",
  async function (taskArguments, hre, runSuper) {
    return hre.run("claimSubnodeWithPublicResolver", { name: taskArguments.name })
      .then(() => hre.run("setAddress", { name: taskArguments.name, address: taskArguments.address }));
  }
).addParam("name", "The name of the node")
.addParam("address", "The address to set")

task(
  "deployContractToSubnode",
  "Deploys a contract and then claims the subnode and sets the address to the newly deployed contract",
  async function (taskArguments, hre, runSuper) {
    const name = taskArguments.name;
    console.log(`Claiming ${name}`);
    await hre.run('claimSubnodeWithPublicResolver', { name: name });
    const contract = await hre.run('deployContract', {
      modulePath: taskArguments.modulePath,
      contractName: taskArguments.contractName,
      args: taskArguments.args,
    });
    console.log(`Setting address of ${name} to ${contract.address}`)
    await hre.run("setAddress", { name: name, address: contract.address });
    return contract
  }
)
.addOptionalParam("modulePath", "The path to the module")
.addParam("contractName", "The contract name within the module")
.addParam("name", "The name of the node")
.addOptionalVariadicPositionalParam("args", "Additional contract constructor arguments")

task(
  "sendEth",
  "Send ethereum to an address",
  async function (taskArguments, hre, runSuper) {
    const signer = await hre.run("getEnsSigner")
    const transaction = await signer.populateTransaction({
      to: taskArguments.to,
      value: taskArguments.value,
      type: 1,
      gasLimit: 21000
    })
    return hre.run("executeTransaction", { transaction: transaction })
  }
).addParam("to", "The address or ens name to send to")
.addParam("value", "The value in wei to send")

task(
  "getEnsNode",
  "Gets the bytes32 representation of an ENS node for a given name and logs it to the console",
  async function (taskArguments, hre, runSuper) {
    const ensNode = namehash.hash(taskArguments.name);
    console.log(`ENS Node for ${taskArguments.name}: ${ensNode}`);
    return ensNode;
  }
).addParam("name", "The name to convert into a bytes32 ENS node");

module.exports = config;
