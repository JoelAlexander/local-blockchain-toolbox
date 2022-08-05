require("@nomiclabs/hardhat-ethers");
const config = require('./hardhat.config.json');
const localNetwork = require('./network.json')
config.defaultNetwork = 'local'
config.networks = { local: localNetwork }
module.exports = config;
