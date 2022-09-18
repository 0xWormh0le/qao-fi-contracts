require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require("solidity-coverage");
require('hardhat-deploy');
require('dotenv').config();

const benchmark = require("./tasks/benchmark");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

const ALCHEMY_KEY = process.env.ALCHEMY_KEY || 'sample-alchemy-key'
const INFURA_PROJECT_ID = process.env.INFURA_PROJECT_ID || 'sample-infura-key'
const INFURA_PROJECT_SECRET = process.env.INFURA_PROJECT_SECRET || 'sample-infura-key'
const MNEMONIC = process.env.MNEMONIC || 'sample-mnemonic'
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || 'etherscan-api-key'

benchmark({
  // etherscan: ETHERSCAN_API_KEY,
  // alchemy: ALCHEMY_KEY,
  infura: {
    projectId: INFURA_PROJECT_ID,
    projectSecret: INFURA_PROJECT_SECRET
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

module.exports = {
  solidity: "0.8.4",
  namedAccounts: {
    deployer: 0,
  },
  networks: {
    ropsten: {
      url: `https://ropsten.infura.io/v3/${INFURA_PROJECT_ID}`,
      // url: `https://eth-ropsten.alchemyapi.io/v2/${ALCHEMY_KEY}`,
      accounts: {
        mnemonic: MNEMONIC
      }
    }
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY
  }
};
