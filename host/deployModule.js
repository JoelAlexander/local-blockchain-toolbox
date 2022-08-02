const namehash = require('eth-ens-namehash')
const utils = require('./utils.js')
const ensUtils = require('./ensUtils.js')

async function deploy() {
  const rootNode = namehash.hash('')
  const ethLabel = ethers.utils.id('eth')
  const ethNode = namehash.hash('eth')

  const ensRegistry = await ensUtils.getEnsRegistry()
  const provider = await ensUtils.getEnsProvider()

  await ensUtils.deployContractToName("FIFSRegistrar", "registrar.eth", ensRegistry.address, ethNode).then((registrar) => {
    console.log(`Giving .eth namespace to registrar.eth`)
    return utils.waitForConfirmation((overrides) => {
      return ensRegistry.setSubnodeOwner(rootNode, ethLabel, registrar.address)
    }).then((receipt) => {
      console.log(`Done!`)
    })
  })

  const ethRegistrarAddress = await provider.resolveName('registrar.eth')
    .then((resolved) => {
      if (resolved) {
        console.log(`registrar.eth found: ${resolved}`)
        return resolved
      } else {
        console.log(`registrar.eth not found`)
      }
    })
}

deploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
