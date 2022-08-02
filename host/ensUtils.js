const environment = require('./environment.json')
const namehash = require('eth-ens-namehash')
const utils = require('./utils')

async function getEnsProvider() {
  const signer = utils.getSigner()
  return new ethers.providers.JsonRpcProvider({
    url: environment.blockchainUrl
  }, {
    chainId: environment.chainId,
    ensAddress: environment.ensAddress
  })
}

async function getPublicResolver() {
  const provider = await getEnsProvider()
  const publicResolverAddress = await provider.resolveName('resolver')
  const PublicResolver = await ethers.getContractFactory("PublicResolver")
  return PublicResolver.attach(publicResolverAddress)
}

async function getEnsRegistry() {
  const ENSRegistry = await ethers.getContractFactory("ENSRegistry")
  return ENSRegistry.attach(environment.ensAddress)
}

async function claimName(name, owner) {
  const ensRegistry = await getEnsRegistry()
  const subnames = name.split('.').reverse()
  var promise = Promise.resolve(true)
  for (var i = 0; i < subnames.length; i++) {
    const nodeName = subnames.slice(0, i).reverse().join('.')
    const subname = subnames[i]
    promise = promise.then((result) => {
      const label = ethers.utils.id(subname)
      const node = namehash.hash(nodeName)
      const displayName = (node === "0x0000000000000000000000000000000000000000000000000000000000000000") ? subname : `${subname}.${nodeName}`
      console.log(`Setting owner of .${displayName} to ${owner}`)
      return utils.waitForConfirmation((overrides) => {
        return ensRegistry.setSubnodeOwner(node, label, owner, overrides)
      })
    })
  }
  return promise
}

async function deployContractToName(contractName, name, ...args) {

  const signer = await utils.getSigner()
  const provider = await getEnsProvider()
  const ensRegistry = await getEnsRegistry()
  const publicResolver = await getPublicResolver()

  const startDeployContract = () => {
    return utils.deployContract(contractName, ...args)
  }

  const node = namehash.hash(name)
  return provider.resolveName(name).then((address) => {
    if (address) {
      return Promise.reject(`${name} already taken!`)
    }
    return claimName(name, signer.address).then(() => {
      console.log(`Deploying contract ${contractName}`)
      return startDeployContract().then((contract) => {
        console.log(`Setting resolver for ${name} to public resolver`)
        return utils.waitForConfirmation((overrides) => {
          return ensRegistry.setResolver(node, publicResolver.address, overrides)
        }).then((receipt) => {
          console.log(`Setting address for ${name} to new contract address ${contract.address}`)
          return utils.waitForConfirmation((overrides) => {
            return publicResolver['setAddr(bytes32,address)'](node, contract.address, overrides)
          }).then((receipt) => {
            console.log(`Deployment of ${contractName} at ${name} complete`)
            return contract
          })
        })
      })
    })
  })
}

module.exports.deployContractToName = deployContractToName
module.exports.claimName = claimName
module.exports.getEnsRegistry = getEnsRegistry
module.exports.getPublicResolver = getPublicResolver
module.exports.getEnsProvider = getEnsProvider
