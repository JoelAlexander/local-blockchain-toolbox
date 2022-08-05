const environment = require('./../environment.json')
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

async function setPublicResolverAddr(node, address) {
  const publicResolver = await getPublicResolver()
  return utils.waitForConfirmation((overrides) => {
    return publicResolver['setAddr(bytes32,address)'](node, address, overrides)
  })
}

async function setPublicResolver(node) {
  const ensRegistry = await getEnsRegistry()
  const publicResolver = await getPublicResolver()
  return utils.waitForConfirmation((overrides) => {
    return ensRegistry.setResolver(node, publicResolver.address, overrides)
  })
}

async function setSubnodeOwner(node, label, owner) {
  const ensRegistry = await getEnsRegistry()
  return utils.waitForConfirmation((overrides) => {
    return ensRegistry.setSubnodeOwner(node, label, owner, overrides)
  })
}

async function claimSubnode(node, label) {
  const signer = await utils.getSigner()
  return setSubnodeOwner(node, label, signer.address)
}

function leafLabelAndNode(name) {
  const names = name.split('.')
  if (names.lenth === 0) {
    throw "Name must not be empty"
  }
  const leaf = names[0]
  const label = ethers.utils.id(leaf)
  const nodeString = names.length === 1 ? '' : names.slice(1, names.length).join('.')
  const node = namehash.hash(nodeString)
  return [label, node]
}

async function createFifsTldNamespace(tld) {
  const ensRegistry = await getEnsRegistry()
  const publicResolver = await getPublicResolver()
  const registrarName = `registrar.${tld}`
  const [tldLabel, rootNode] = leafLabelAndNode(tld)
  const [registrarLabel, tldNode] = leafLabelAndNode(registrarName)
  const registrarNode = namehash.hash(registrarName)
  console.log(`Deploying new FIFSRegistrar`)
  return utils.deployContract("FIFSRegistrar", ensRegistry.address, tldNode).then((contract) => {
    console.log(`Claiming .${tld}`)
    return claimSubnode(rootNode, tldLabel).then((receipt) => {
      console.log(`Claiming registrar.${tld}`)
      return claimSubnode(tldNode, registrarLabel).then((receipt) => {
        console.log(`Setting resolver for registrar.${tld} to the public resolver`)
        return setPublicResolver(registrarNode).then((receipt) => {
          console.log(`Setting address for registrar.${tld} to FIFSRegistrar at ${contract.address}`)
          return setPublicResolverAddr(registrarNode, contract.address).then((receipt) => {
            console.log(`Changing owner of .${tld} to FIFSRegistrar at ${contract.address}`)
            return setSubnodeOwner(rootNode, tldLabel, contract.address).then((receipt) => {
              console.log(`FIFSRegistrar 'registrar.${tld}' now owns .${tld} namespace`)
            })
          })
        })
      })
    })
  })
}

module.exports.getEnsRegistry = getEnsRegistry
module.exports.getPublicResolver = getPublicResolver
module.exports.getEnsProvider = getEnsProvider
module.exports.claimSubnode = claimSubnode
module.exports.setPublicResolver = setPublicResolver
module.exports.setPublicResolverAddr = setPublicResolverAddr
module.exports.createFifsTldNamespace = createFifsTldNamespace
module.exports.leafLabelAndNode = leafLabelAndNode
module.exports.hash = namehash.hash
