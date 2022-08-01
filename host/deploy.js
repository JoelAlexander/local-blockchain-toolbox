const path = require('node:path')
const fs = require('fs')
const environment = require('./environment.json')
const namehash = require('eth-ens-namehash')

async function getGasPriceAndDeploy(contractName, signer, ...args) {
  const gasPrice = await signer.getGasPrice().then((gasPrice) => {
    console.log(`The gas price is: ${gasPrice}`)
    return gasPrice
  })

  const contractFactory = await ethers.getContractFactory(contractName)
  const contract = await contractFactory.deploy(...args, { gasPrice: gasPrice })
  console.log(`${contractName} deploying to: ${contract.address}`)
  return contract.deployTransaction.wait().then(() => {
    console.log(`${contractName} deployment confirmed`)
    return contract
  })
}

async function deploy() {
  const signer = await ethers.getSigners().then((signers) => { return signers[0] })

  const transactionCount = await signer.getTransactionCount()
  if (transactionCount === 0) {
    await getGasPriceAndDeploy('Faucet', signer)
  } else {
    console.log(`Transaction count non-zero: skipping Faucet deployment`)
  }

  if (!environment.ensAddress) {
    await getGasPriceAndDeploy('ENSDeployment', signer).then((ensDeployment) => {
      return ensDeployment.ens()
    }).then((ensAddress) => {
      console.log(`ENS instance at: ${ensAddress}`)
      environment.ensAddress = ensAddress
      fs.writeFileSync(path.join(__dirname, 'environment.json'), JSON.stringify(environment))
    })
  } else {
    console.log(`ENS already deployed to ${environment.ensAddress}`)
  }

  var provider = ethers.provider
  const defaultNetwork = await provider.getNetwork()
  if (!defaultNetwork.ensAddress) {
    console.log(`Upgrading provider to use ENS address`)
    defaultNetwork.ensAddress = environment.ensAddress
    provider = new ethers.providers.JsonRpcProvider(
      { url: environment.blockchainUrl },
      defaultNetwork
    )
  }

  const publicResolverAddress = await provider.resolveName('resolver').then((address) => {
    return address
  }, (err) => {
    console.log(err)
  })

  const PublicResolver = await ethers.getContractFactory("PublicResolver")
  const publicResolver = PublicResolver.attach(publicResolverAddress)
  console.log(`Public resolver: ${JSON.stringify(publicResolver, null, 2)}`)

  const ENSRegistry = await ethers.getContractFactory("ENSRegistry")
  const ensRegistry = ENSRegistry.attach(environment.ensAddress)
  const rootNode = ethers.utils.formatBytes32String('')
  console.log(`Public resolver: ${JSON.stringify(ensRegistry, null, 2)}`)

  const ethLabel = ethers.utils.id('eth')
  const registrarLabel = ethers.utils.id('registrar')
  const ethNode = namehash.hash('eth')
  const ethRegistrarNode = namehash.hash('registrar.eth')
  await ensRegistry.owner(rootNode).then((address) => {
    if (address === signer.address) {
      console.log("Root namespace is owned by the creator account")
      return ensRegistry.owner(ethNode).then((address) => {
        if (address === ethers.constants.AddressZero) {
          console.log(`Claiming .eth namespace with new FIFSRegistrar`)
          return getGasPriceAndDeploy("FIFSRegistrar", signer, ensRegistry.address, ethNode).then((fifsRegistrar) => {
            console.log(`Setting .eth subnode owner to new FIFSRegistrar: ${fifsRegistrar.address}`)
            return ensRegistry.setSubnodeOwner(rootNode, ethLabel, fifsRegistrar.address).then((response) => {
              return response.wait().then(() => {
                console.log(`Registering registrar.eth`)
                const fifsRegistrarConnected = fifsRegistrar.connect(signer)
                return fifsRegistrarConnected.register(registrarLabel, signer.address).then((response) => {
                  return response.wait().then(() => {
                    console.log(`Setting resolver for registrar.eth to the public resolver ${publicResolver.address}`)
                    return ensRegistry.setResolver(ethRegistrarNode, publicResolver.address).then((response) => {
                      return response.wait().then(() => {
                        console.log(`Setting registrar.eth address to ${fifsRegistrar.address} in public resolver`)
                        return publicResolver['setAddr(bytes32,address)'](ethRegistrarNode, fifsRegistrar.address).then((response) => {
                          return response.wait().then(() => {
                            console.log('.eth public namespace setup complete')
                          })
                        })
                      })
                    })
                  })
                })
              })
            })
          })
        } else {
          console.log(`.eth namespace already owned by ${address}`)
        }
      })
    } else {
      console.log("Root namespace is NOT owned by the creator account")
    }
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

// const path = require('node:path')
// const ethers = require('ethers')
// const ethJsUtil = require('ethereumjs-util')
// const fs = require('fs');
//
// const args = process.argv.slice(2)
// const creatorFile = args[0]
// const environmentFile = args[1]
// const compiledContractDirectory = args[2]
// const creator = require(creatorFile)
// const environment = require(environmentFile)
//
// const rpcProvider = new ethers.providers.JsonRpcProvider(
//   { url: environment.blockchainUrl },
//   { chainId: environment.chainId })
//
// const creatorWallet = new ethers.Wallet(creator.privateKey, rpcProvider)
//
// const importContract = (contractName) => {
//   return require(path.join(
//     compiledContractDirectory,
//     'contracts',
//     `${contractName}.sol`,
//     `${contractName}.json`))
// }
//
// const getContractFactory = (contractName) => {
//   const contract = importContract(contractName)
//   return new ethers.ContractFactory(contract.abi, contract.bytecode, creatorWallet)
// }
//
// const getContract = (contractName, contractAddress) => {
//   const contract = importContract(contractName)
//   return new ethers.Contract(contractAddress, contract.abi, creatorWallet)
// }
//
// getContractFactory('ENSDeployment').deploy().then((contract) => {
//   contract.deployTransaction.wait().then((transactionReceipt) => {
//     console.log(`Received transaction receipt ${transactionReceipt}`)
//     console.log(`Contract address is ${transactionReceipt.contractAddress}`)
//     getContract('ENSDeployment', transactionReceipt.contractAddress).ens().then((ensAddress) => {
//       console.log(`ENS address is ${ensAddress}`)
//       environment.ensAddress = ensAddress
//       fs.writeFileSync(environmentFile, JSON.stringify(environment))
//     }, (err) => {
//       console.log(err)
//     })
//   }, (err) => {
//     console.log(err)
//   })
// }, (err) => {
//   console.log(err)
// })
