require("@nomiclabs/hardhat-ethers")
const deploy = require('./scripts/deploy.js')
const config = require('./hardhat.config.json')
const utils = require('./scripts/utils.js')
const ensUtils = require('./scripts/ensUtils.js')

try {
  const localNetwork = require('./network.json')
  config.defaultNetwork = 'local'
  config.networks = { local: localNetwork }
} catch (e) {}

task(
  "checkBalance",
  "Checks the balance of the creator account",
  async function (taskArguments, hre, runSuper) {
    const signer = await utils.getSigner()
    return signer.getBalance().then((balance) => {
      console.log(`${signer.address}: ${balance}`)
    })
  }
)

task(
  "resolveName",
  "Resolves the name on ENS",
  async function (taskArguments, hre, runSuper) {
    const provider = await ensUtils.getEnsProvider()
    return provider.resolveName(taskArguments.name).then((address) => {
      console.log(`${taskArguments.name}: ${address}`)
    })
  }
).addParam("name", "The name to resolve")

task(
  "makeGenesis",
  "Makes the genesis file for the local blockchain",
  async function (taskArguments, hre, runSuper) {
    return deploy.makeGenesis(taskArguments)
  }
).addParam("chainId", "The chainId of the blockchain")
.addParam("sealerAddress", "The public key of the intial sealer account")
.addParam("genesisFile", "The path to the genesis file")
.addParam("creatorFile", "The path to the creator file");

task(
  "deployGenesis",
  "Deploys the first contracts onto a fresh blockchain.",
  async function (taskArguments, hre, runSuper) {
    return deploy.deployGenesis()
  }
);

task(
  "configureModule",
  "Writes a blockchain configuration file into a module directory, preparing it to be built.",
  async function (taskArguments, hre, runSuper) {
    return deploy.configureModule(taskArguments)
  }
).addParam("modulePath", "The path to the module");

task(
  "deployModule",
  "Checks a module for expected contracts and deploy its contracts to the blockchain.",
  async function (taskArguments, hre, runSuper) {
    return deploy.deployModule(taskArguments)
  }
).addParam("modulePath", "The path to the module");

task(
  "sendEth",
  "Sends ether from the creator account to the specified address",
  async function (taskArguments, hre, runSuper) {
    return utils.sendEth(taskArguments.amount, taskArguments.address)
  }
)
.addParam("amount", "The amount in eth")
.addParam("address", "The receipient address");

module.exports = config;
