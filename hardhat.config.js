require("@nomicfoundation/hardhat-ethers")
const ethJsUtil = require('ethereumjs-util')
const fs = require('fs')
const path = require('node:path')
const namehash = require('eth-ens-namehash')
const config = require('./hardhat.config.json')
const { types, task } = require("hardhat/config")

extendEnvironment((hre) => {
  const activeProfilePath = path.join(__dirname, '.local', 'active_profile');
  var activeProfileName = null;
  try {
    activeProfileName = fs.readFileSync(activeProfilePath, 'utf8').trim();
  } catch (error) {}

  if (!activeProfileName || activeProfileName == '') {
    console.warn("No active profile set. Must configure a profile before running most hardhat tasks")
    return
  }
  
  const profilePath = path.join(__dirname, '.local', 'profiles', activeProfileName, 'profile.json');
  const profile = JSON.parse(fs.readFileSync(profilePath, 'utf8'));
  hre.cc = { chainName: profile.chain };

  if (profile.accounts && profile.accounts.length > 0) {
    hre.cc.address = "0x" + profile.accounts[0];

    const keystoreDir = path.join(__dirname, '.local', 'keystore');
    const keystoreFile = fs.readdirSync(keystoreDir).find(file => file.includes(hre.cc.address.slice(2)));
    const keystorePath = path.join(keystoreDir, keystoreFile);
    if (keystorePath && process.env.ACCOUNT_PASSWORD) {
      console.log(`Opening keystore for the active account: ${keystorePath}`);
      try {
          const keystore = fs.readFileSync(keystorePath, 'utf8');
          const wallet = hre.ethers.Wallet.fromEncryptedJsonSync(keystore, process.env.ACCOUNT_PASSWORD);
          console.log('Account unlocked successfully');
          hre.activeLocalSigner = wallet;
      } catch (error) {
          console.error('Failed to unlock account:', error.message);
      }
    }
  }

  // Read the chain ID from the chains directory
  var chainId = null;
  if (profile.chain) {
    const chainDir = path.join(__dirname, '.local', 'chains', profile.chain);
    const genesisPath = path.join(chainDir, 'genesis.json');
    if (fs.existsSync(genesisPath)) {
        const genesis = JSON.parse(fs.readFileSync(genesisPath, 'utf8'));
        hre.cc.chainId = genesis.config.chainId;
    }
  } else {
    console.error(`Genesis file not found for chain: ${profile.chain}`);
  }

  if (profile.rpc && profile.rpc.domain) {
      const rpcDomain = profile.rpc.domain;
      const protocol = rpcDomain === 'localhost' ? 'http' : 'https';
      const port = rpcDomain === 'localhost' ? ':80' : '';
      hre.cc.rpcUrl = `${protocol}://${rpcDomain}${port}/`;
      hre.cc.ens = profile.ens;
      console.log(`Chain ID: ${hre.cc.chainId}`);
      console.log(`RPC: ${hre.cc.rpcUrl}`);
      console.log(`ENS: ${hre.cc.ens}`);
  } else {
      console.error('RPC domain is not defined in the active profile.');
  }
});

task(
  "createFundedAccount",
  "Creates and funds a account",
  async function (taskArguments, hre, runSuper) {
    const wallet = hre.ethers.Wallet.createRandom()
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
      chainId: hre.cc.chainId,
      url: hre.cc.rpcUrl,
      ens: hre.cc.ens
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
    const modulePath = taskArguments.modulePath
    const manifestPath = path.join(modulePath, 'manifest.json')
    const manifest = require(manifestPath)

    const deployContractPromise = async ({name, source, args}) => {
      console.log(`Deploying contract ${source} to ${name} with args ${args}`);
      await hre.run('deployContractToSubnode', {
        modulePath: taskArguments.modulePath,
        contractName: source,
        name: name,
        args: args })
    };

    if(manifest.deploy && (manifest.deploy.ens || manifest.deploy.resolver)){
        return Promise.reject(`'ens, and resolver' are reserved keys and cannot be used in the deploy list.`);
    }

    const rootName = `${manifest.name}`
    const specifiedDeployment = (taskArguments.deploy && taskArguments.deploy.length > 0) || taskArguments.deployRoot
    const rootDeploymentConfig = { name: rootName, source: manifest.source, args: manifest.args, ownSubdomain: true }
    const matchingDeploymentConfigs = Object.entries(manifest.deploy)
      .map(([key, deploymentConfig]) => [`${key}.${rootName}`, deploymentConfig])
      .filter(([name, _]) => !specifiedDeployment || (taskArguments.deploy && taskArguments.deploy[name]))
      .map(([name, deploymentConfig]) => { return { name: name, ...deploymentConfig } })
    const allDeploymentConfigs = [rootDeploymentConfig, ...matchingDeploymentConfigs]
    const deploymentConfigs = specifiedDeployment ?
      (taskArguments.deployRoot ? allDeploymentConfigs : matchingDeploymentConfigs) :
      (await Promise.all(allDeploymentConfigs.map(({name, ..._}) => {
        console.log(`Getting address for ${name}`)
        return hre.run("getAddress", { name: name })
      })).then(([...existingAddresses]) => {
        console.log(`${JSON.stringify(existingAddresses)}`)
        return allDeploymentConfigs.filter((_, index) => existingAddresses[index] == null)
      }))

    console.log(`Deploying contracts: ${JSON.stringify(deploymentConfigs.map(i => i.name))}`)
    for (let index = 0; index < deploymentConfigs.length; index++) {
      const config = deploymentConfigs[index]
      console.log(`Deploying ${config.name}`)
      await deployContractPromise(config)
    }
    for (let index = 0; index < deploymentConfigs.length; index++) {
      const config = deploymentConfigs[index]
      if (config.ownSubdomain) {
        console.log(`Transfering ownership of ${config.name} to ${config.name}`)
        await hre.run('setSubnodeOwner', { name: config.name, owner: config.name })
      }
    }
    console.log(`Module ${rootName} deployed`);
    return Promise.resolve();
  }
).addParam('modulePath', 'The absolute path to the module.')
.addFlag('deployRoot', 'Explicitly redeploy the root contract')
.addOptionalVariadicPositionalParam("deploy", "List of contracts to be deployed");

task(
  "getGasPrice",
  "Gets the current gas price",
  async function (taskArguments, hre, runSuper) {
    const provider = await hre.run("getEnsProvider")
    return provider.getFeeData().then((feeData) => {
      return feeData.gasPrice
    });
  }
)

task(
  "getBalance",
  "Checks the balance of the current account",
  async function (taskArguments, hre, runSuper) {
    const provider = await hre.run("getEnsProvider")
    const address = taskArguments.address ? taskArguments.address : hre.cc.address
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
        return gasPrice + (gasPrice / BigInt(40))
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
    if (!hre.cc.ens) {
      return Promise.resolve(null)
    }

    return hre.run(
      "getDeployedContract",
      { contractName: "@local-blockchain-toolbox/ens-contracts/artifacts/contracts/registry/ENSRegistry.sol:ENSRegistry",
        address: hre.cc.ens }
    )
  }
)

task(
  "getEnsProvider",
  "Gets an ENS enabled provider for the active chain",
  async function (taskArguments, hre, runSuper) {
    const networkish = {
      name: hre.cc.chainName,
      chainId: hre.cc.chainId
    }
    if (hre.cc.ens) {
      networkish.ensAddress = hre.cc.ens
    }
    return Promise.resolve(
      new hre.ethers.JsonRpcProvider(hre.cc.rpcUrl, networkish));
  }
)

task(
  "getEnsSigner",
  "Gets an ENS enabled signer for the active chain",
  async function (taskArguments, hre, runSuper) {
    return hre.run(
      "getEnsProvider"
    ).then((ensProvider) => {
      return hre.activeLocalSigner.connect(ensProvider)
    })
  }
)

task(
  "getContractFactory",
  "Gets a contract factory",
  async function (taskArguments, hre, runSuper) {
    const provider = await hre.run("getEnsProvider")
    const contractFactory = await hre.ethers.getContractFactory(taskArguments.contractName, provider)
    return contractFactory.connect(provider)
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
  "getCode",
  "Gets the deployed code for an address",
  async function (taskArguments, hre, runSuper) {
    const provider = await hre.run("getEnsProvider")
    return provider.getCode(taskArguments.address).then(console.log)
  }
).addParam("address", "The address of the contract")

task(
  "getPublicResolver",
  "Gets the public ENS resolver contract",
  async function (taskArguments, hre, runSuper) {
    const provider = await hre.run("getEnsProvider")
    const resolverAddress = await provider.resolveName('resolver')

    return resolverAddress === null ? null :
      await hre.run("getDeployedContract", {
        contractName: "@local-blockchain-toolbox/ens-contracts/artifacts/contracts/resolvers/PublicResolver.sol:PublicResolver",
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
    const signer = await hre.run("getEnsSigner")
    const args = taskArguments.args ? taskArguments.args : []
    var contractFactory = (taskArguments.modulePath ? 
      await hre.run("getModuleContractFactory", { modulePath: taskArguments.modulePath, contractName: taskArguments.contractName }) :
      await hre.run("getContractFactory", { contractName: taskArguments.contractName })).connect(signer)
    const gasPrice = await hre.run("getGasPrice")
    const contract = await contractFactory.deploy(...args, { gasPrice: gasPrice })
    //console.log(`${JSON.stringify(contract)}`)
    console.log(`${taskArguments.contractName} deploying to: ${contract.target}`)
    return contract.waitForDeployment().then((deployedContract) => {
      console.log(`${taskArguments.contractName} deployment confirmed`)
      //console.log(`${JSON.stringify(deployedContract)}`)
      return deployedContract
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
    const transaction = await contract[taskArguments.method].populateTransaction(...args, overrides)
    return hre.run("executeTransaction", { transaction: transaction }).then(console.log)
  }
).addParam("modulePath", "The path to the module")
.addParam("contractName", "The name or fully qualified name of the contract")
.addParam("address", "The address of the deployed contract")
.addParam("method", "The method name to call")
.addOptionalParam("value", "The value to send in the contract")
.addOptionalVariadicPositionalParam("args", "Additional contract constructor arguments")

const ReverseRegistrarContractName = '@local-blockchain-toolbox/contract-primitives/artifacts/contracts/IntrinsicRegistrar.sol:IntrinsicRegistrar'

task(
  "getReverseRegistrar",
  "Gets the reverse registrar at addr.reverse",
  async function (taskArguments, hre, runSuper) {
    const ensSigner = await hre.run("getEnsSigner")
    const existingReverseRegistrar = await ensSigner.resolveName('addr.reverse')
    if (existingReverseRegistrar) {
      return await hre.run('getDeployedContract',
        { contractName: ReverseRegistrarContractName,
          address: existingReverseRegistrar })
    } else {
      return null
    }
  }
)

task(
  "deployReverseRegistrar",
  "Deploys the custom reverse registrar: IntrinsicRegistrar",
  async function (taskArguments, hre, runSuper) {
    console.log(`Deploying reverse registrar`)
    const ensRegistry = await hre.run("getEnsRegistry")
    const publicResolver = await hre.run("getPublicResolver")
    return await hre.run('deployContractToSubnode',
      { name: 'addr.reverse', contractName: ReverseRegistrarContractName, args: [ ensRegistry.target ]})
      .then((deployedReverseRegistrar) => {
          console.log(`Setting ownership of addr.reverse to ${deployedReverseRegistrar.target}`)
          return hre.run('setSubnodeOwner', { name: 'addr.reverse', owner: deployedReverseRegistrar.target })
      })
  }
)

task(
  "deployPublicResolver",
  "Deploys the public resolver",
  async function (taskArguments, hre, runSuper) {
    const exec = (pt) => {
      return pt.then((t) => {
        return hre.run("executeTransaction", { transaction: t })
      })
    }

    const resolverNode = namehash.hash('resolver')
    const publicResolverContractName = "@local-blockchain-toolbox/ens-contracts/artifacts/contracts/resolvers/PublicResolver.sol:PublicResolver"
    const ensRegistry = await hre.run("getEnsRegistry")
    console.log(`Deploying public resolver`)
    return hre.run("deployContract", { contractName: publicResolverContractName , args: [ ensRegistry.target ]})
    .then((deployedResolver) => {
      console.log(`Claiming name: resolver`)
      return hre.run("claimSubnode", { name: 'resolver' })
      .then(() => {
        console.log(`Setting resolver of node 'resolver' to ${deployedResolver.target}`)
        return exec(ensRegistry.setResolver.populateTransaction(resolverNode, deployedResolver.target)).then(() => {
          console.log(`Setting address of resolver to ${deployedResolver.target}`)
          return exec(deployedResolver['setAddr(bytes32,address)'].populateTransaction(resolverNode, deployedResolver.target))
          .then(() => {
            return deployedResolver
          })
        })
    })})
  }
)

task(
  "deployEns",
  "Deploys an Ens registry.",
  async function (taskArguments, hre, runSuper) {
    const deployedEnsRegistry = await hre.run("getEnsRegistry")
      .then((existingEnsRegistry) => {
        if (existingEnsRegistry) {
          return existingEnsRegistry
        } else {
          console.log(`Deploying ENS Registry`)
          return hre.run(
            "deployContract",
            { contractName: "@local-blockchain-toolbox/ens-contracts/artifacts/contracts/registry/ENSRegistry.sol:ENSRegistry"}
          ).then((newlyDeployedEnsRegistry) => {
            hre.cc.ens = newlyDeployedEnsRegistry.target;
            return newlyDeployedEnsRegistry
          })
        }
      })
    
    console.log(`Using ENSRegistry: ${deployedEnsRegistry.target}`)
    const existingResolverAddress = await hre.run("getResolver")
    if (existingResolverAddress) {
      console.log(`Public resolver already detected, skipping deployment`)
    } else {
      await hre.run("deployPublicResolver")
    }

    const ensSigner = await hre.run("getEnsSigner")
    const ensRegistry = await Promise.resolve(deployedEnsRegistry.connect(ensSigner))
    var existingReverseRegistrar = await hre.run('getReverseRegistrar')
    if (!existingReverseRegistrar) {
      console.log(`No existing reverse registrar found`)
      existingReverseRegistrar = await hre.run('deployReverseRegistrar')
    } 
    console.log(`Using reverse registrar: ${existingReverseRegistrar.target}`)

    const resolvedEnsAddress = await hre.run('getAddress', { name: 'ens' })
    if (!resolvedEnsAddress || (resolvedEnsAddress != deployedEnsRegistry.target)) {
      console.log(`Setting 'ens' to: ${deployedEnsRegistry.target}`)
      await hre.run('claimSubnodeWithAddress', { name: 'ens', address: deployedEnsRegistry.target })
      console.log(`${deployedEnsRegistry.target}`)
    } else {
      console.log(`'ens' already points to deployed registry at: ${resolvedEnsAddress}`)
      console.log(`${resolvedEnsAddress}`)
    }
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
      const label = hre.ethers.solidityPackedKeccak256(["string"], [leaf])
      const nodeString = names.slice(1, names.length).join('.')
      const node = namehash.hash(nodeString)
      return [label, node]
    }

    const signer = await hre.run("getEnsSigner")
    const ensRegistry = await hre.run("getEnsRegistry").then((registry) => registry.connect(signer))
    const [label, node] = labelAndNode(taskArguments.name)
    const transaction = await ensRegistry.setSubnodeOwner.populateTransaction(node, label, taskArguments.owner)
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
    var resolved = null;
    try {
      resolved = await provider.getResolver(name)
    } catch (e) {}
    return resolved
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
    const transaction = await ensRegistry.setResolver.populateTransaction(node, taskArguments.resolver, { gasPrice: gasPrice })
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
    if (currentResolver === publicResolver.target) {
      console.log(`The public resolver for the node ${name} is already set`);
      return;
    }

    console.log(`Setting the public resolver for the node ${name}`);
    return await hre.run("setResolver", { name: taskArguments.name, resolver: publicResolver.target });
  }
).addParam("name", "The name of the node");

task(
  "setPublicResolverAddress",
  "Sets the owner of an ENS subnode",
  async function (taskArguments, hre, runSuper) {
    const node = namehash.hash(taskArguments.name)
    const resolver = await hre.run("getPublicResolver")
    const transaction = await resolver['setAddr(bytes32,address)'].populateTransaction(node, taskArguments.address)
    return hre.run("executeTransaction", { transaction: transaction })
  }
).addParam("name", "The name of the node")
.addParam("address", "The address to set")

task(
  "setAddress",
  "Sets the address on the current resolver of an ENS node",
  async function (taskArguments, hre, runSuper) {
    const node = namehash.hash(taskArguments.name)
    const signer = await hre.run("getEnsSigner")
    const ensRegistry = await hre.run("getEnsRegistry");
    const currentResolverAddress = await ensRegistry.resolver(node);
    if (currentResolverAddress === hre.ethers.ZeroAddress) {
      throw new Error(`No resolver set for ENS node ${taskArguments.name}`);
    }

    const currentResolver = await hre.ethers.getContractAt(
      "@local-blockchain-toolbox/ens-contracts/artifacts/contracts/resolvers/Resolver.sol:Resolver",
      currentResolverAddress,
      signer)

    const currentAddress = await currentResolver['addr(bytes32)'](node);
    if (currentAddress.toLowerCase() === taskArguments.address.toLowerCase()) {
      console.log(`The address for the node ${taskArguments.name} is already set to the desired value`);
      return;
    }

    const transaction = await currentResolver['setAddr(bytes32,address)'].populateTransaction(node, taskArguments.address)
    return hre.run("executeTransaction", { transaction: transaction })
  }
).addParam("name", "The name of the node")
.addParam("address", "The address to set")

task(
  "setABI",
  "Sets the abi on the current resolver of an ENS node",
  async function (taskArguments, hre, runSuper) {
    const node = namehash.hash(taskArguments.name)
    const signer = await hre.run("getEnsSigner")
    const ensRegistry = await hre.run("getEnsRegistry");
    const currentResolverAddress = await ensRegistry.resolver(node);
    if (currentResolverAddress === hre.ethers.ZeroAddress) {
      throw new Error(`No resolver set for ENS node ${taskArguments.name}`);
    }

    const currentResolver = await hre.ethers.getContractAt(
      "@local-blockchain-toolbox/ens-contracts/artifacts/contracts/resolvers/Resolver.sol:Resolver",
      currentResolverAddress,
      signer)

    const bytes = hre.ethers.toUtf8Bytes(taskArguments.abi)
    const transaction = await currentResolver['setABI(bytes32,uint256,bytes)'].populateTransaction(node, 0x1, bytes)
    return hre.run("executeTransaction", { transaction: transaction })
  }
).addParam("name", "The name of the node")
.addParam("abi", "The json ABI to set")

task(
  "getABI",
  "Gets the ABI on the current resolver of an ENS node",
  async function (taskArguments, hre, runSuper) {
    const node = namehash.hash(taskArguments.name)
    const signer = await hre.run("getEnsSigner")
    const ensRegistry = await hre.run("getEnsRegistry");
    const currentResolverAddress = await ensRegistry.resolver(node);
    if (currentResolverAddress === hre.ethers.ZeroAddress) {
      throw new Error(`No resolver set for ENS node ${taskArguments.name}`);
    }

    const currentResolver = await hre.ethers.getContractAt(
      "@local-blockchain-toolbox/ens-contracts/artifacts/contracts/resolvers/Resolver.sol:Resolver",
      currentResolverAddress,
      signer)

    const abi = await currentResolver['ABI(bytes32,uint256)'](node, 0x1)
    console.log(JSON.stringify(abi))
    return
  }
).addParam("name", "The name of the node")

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
    const subnamesToClaim = await (async () => {
      const nodes = name.split('.').reverse()
      const nodePath = [
        ['', '0x0000000000000000000000000000000000000000000000000000000000000000'],
        ...(nodes.reduce((result, element) => {
          const currentName = result.length === 0 ? element : `${element}.${result[result.length - 1][0]}`
          const node = namehash.hash(currentName)
          return [...result, [currentName, node]]
        }, []))
      ].reverse()

      return Promise.all(nodePath.map(([nodename, node]) => ensRegistry.owner(node).then((currentOwner) => {
          return currentOwner === signer.address
        })))
        .then((ownedArray) => {
          const firstOwnedNode = ownedArray.indexOf(true)
          if (firstOwnedNode === -1) {
            console.log(`Cannot claim ${name}. No parent nodes are owned by the current signer`)
            return []
          } else if (firstOwnedNode === 0) {
            console.log(`Cannot claim ${name}. Node is already owned by the current signer`)
            return []
          } else {
            const subnodesToClaim = nodePath.slice(0, firstOwnedNode)
            if (subnodesToClaim.length === 0) {
              console.log(`Name ${name} already claimed. All nodes are owned by the current signer`)
            }
            return subnodesToClaim.map(([name, _]) => name).reverse()
          }
        })
    })()

    if (subnamesToClaim.length === 0) {
      console.log(`Nothing to do, exiting.`)
      return Promise.resolve()
    }

    console.log(`Claiming names in sequence: ${JSON.stringify(subnamesToClaim)}`)

    return subnamesToClaim.reduce((promise, name) => {
      return promise.then(() => {
        return hre.run("setSubnodeOwner", {
          name: name,
          owner: signer.address
        })
      })
    }, Promise.resolve())
  }
).addParam("name", "The name of the node")

task(
  "claimSubnodeWithPublicResolver",
  "Claims the ENS subnode and sets the resolver to the public resolver",
  async function (taskArguments, hre, runSuper) {
    return await hre.run("claimSubnode", { name: taskArguments.name })
      .then(() => {
        console.log(`Setting public resolver`)
        return hre.run("setPublicResolver", { name: taskArguments.name })});
  }
).addParam("name", "The name of the node")

task(
  "claimSubnodeWithAddress",
  "Claims the ENS subnode, sets the resolver to the public resolver, and sets the address",
  async function (taskArguments, hre, runSuper) {
    return await hre.run("claimSubnodeWithPublicResolver", { name: taskArguments.name })
      .then(() => hre.run("setAddress", { name: taskArguments.name, address: taskArguments.address }));
  }
).addParam("name", "The name of the node")
.addParam("address", "The address to set")

task(
  "deployContractToSubnode",
  "Deploys a contract and then claims the subnode and sets the address and the ABI",
  async function (taskArguments, hre, runSuper) {
    const name = taskArguments.name;
    console.log(`Claiming ${name}`);
    await hre.run('claimSubnodeWithPublicResolver', { name: name });
    const contract = await hre.run('deployContract', {
      modulePath: taskArguments.modulePath,
      contractName: taskArguments.contractName,
      args: taskArguments.args,
    });
    console.log(`Setting address of ${name} to ${contract.target}`)
    await hre.run("setAddress", { name: name, address: contract.target });
    console.log(`Setting ABI of ${name}`)
    await hre.run("setABI", { name: name, abi: contract.interface.formatJson() })
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
  "getNode",
  "Gets the bytes32 representation of an ENS node for a given name and logs it to the console",
  async function (taskArguments, hre, runSuper) {
    const ensNode = namehash.hash(taskArguments.name);
    console.log(`ENS Node for ${taskArguments.name}: ${ensNode}`);
    return ensNode;
  }
).addParam("name", "The name to convert into a bytes32 ENS node");

task(
  "getLabel",
  "Gets the bytes32 representation of a label and logs it to the console",
  async function (taskArguments, hre, runSuper) {
    const label = hre.ethers.solidityPackedKeccak256(["string"], [taskArguments.label])
    console.log(`ENS Node for ${taskArguments.label}: ${label}`)
    return label
  }
).addPositionalParam("label", "The name to get the ens label bytes32 of")

task(
  "getSignerAddress",
  "Gets the public address of the current signer and logs it to the console",
  async function (taskArguments, hre, runSuper) {
    const signer = await hre.run("getEnsSigner")
    console.log(`${signer.address}`)
  }
)

task(
  "getEnsName",
  "Gets the ENS name of an address",
  async function (taskArguments, hre, runSuper) {
    const provider = await hre.run("getEnsProvider")
    try {
      const name = await provider.lookupAddress(taskArguments.address);
      if (!name) {
        console.log(`The address ${taskArguments.address} does not have an associated ENS name.`);
      } else {
        console.log(`The ENS name for address ${taskArguments.address} is ${name}.`);
      }
      return name
    } catch (error) {
      console.log(`An error occurred while attempting to get the ENS name: ${error.message}`);
    }
    return null
  }
)
.addParam("address", "The address to check")

module.exports = config;
