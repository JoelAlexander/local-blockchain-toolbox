const utils = require('./utils.js')
const ensUtils = require('./ensUtils.js')

async function deploy() {

  const provider = await ensUtils.getEnsProvider()
  const publicFaucetAddress = await provider.resolveName('faucet.public')
    .then((resolved) => {
      if (resolved) {
        console.log(`faucet.public found: ${resolved}`)
        return resolved
      } else {
        console.log(`faucet.public not found`)
      }
    })

  const tld = 'eth'
  await ensUtils.createFifsTldNamespace(tld)
  const ethRegistrarAddress = await provider.resolveName(['registrar', tld].join('.'))
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
