const path = require('node:path')

function getSigner() {
  return ethers.getSigners().then((signers) => { return signers[0] })
}

async function checkGasPrice() {
  return ethers.provider.getGasPrice().then((gasPrice) => {
    return gasPrice.add(gasPrice.div(40))
  })
}

async function deployModuleContract(modulePath, contractName, ...args) {
  const signer = await getSigner()
  const contractData = require(path.join(modulePath, "artifacts", "contracts", `${contractName}.sol`, `${contractName}.json`))
  const contractFactory = new ethers.ContractFactory(contractData.abi, contractData.bytecode, signer)
  const gasPrice = await checkGasPrice()
  const contract = await contractFactory.deploy(...args, { gasPrice: gasPrice })
  console.log(`${contractName} deploying to: ${contract.address}`)
  return contract.deployTransaction.wait().then(() => {
    console.log(`${contractName} deployment confirmed`)
    return contract
  })
}

async function deployContract(contractName, ...args) {
  const contractFactory = await ethers.getContractFactory(contractName)
  const gasPrice = await checkGasPrice()
  const contract = await contractFactory.deploy(...args, { gasPrice: gasPrice })
  console.log(`${contractName} deploying to: ${contract.address}`)
  return contract.deployTransaction.wait().then(() => {
    console.log(`${contractName} deployment confirmed`)
    return contract
  })
}

async function waitForConfirmation(transactionFactory) {
  const gasPrice = await checkGasPrice()

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

async function sendEth(amount, address) {
  const signer = await getSigner()
  return waitForConfirmation((overrides) => {
    return signer.sendTransaction({
      to: address,
      value: amount,
      gasPrice: overrides.gasPrice
    })
  })
}

module.exports.getSigner = getSigner
module.exports.checkGasPrice = checkGasPrice
module.exports.deployContract = deployContract
module.exports.deployModuleContract = deployModuleContract
module.exports.waitForConfirmation = waitForConfirmation
module.exports.sendEth = sendEth
