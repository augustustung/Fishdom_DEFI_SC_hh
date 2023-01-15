require("@nomiclabs/hardhat-waffle")
require("@nomiclabs/hardhat-ethers")
require('@openzeppelin/hardhat-upgrades')
require("@nomiclabs/hardhat-etherscan")
require('dotenv').config()
// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners()

  for (const account of accounts) {
    console.log(account.address)
  }
})

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const MAINNET_RPC_URL = process.env.MAINNET_RPC_URL || process.env.ALCHEMY_MAINNET_RPC_URL || "https://eth-mainnet.alchemyapi.io/v2/your-api-key"
const GOERLI_RPC_URL = process.env.GOERLI_RPC_URL || "https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161"
const BSC_TESTNET_RPC_URL = process.env.BSC_TESTNET_RPC_URL || "https://data-seed-prebsc-1-s1.binance.org:8545"
const MNEMONIC = process.env.MNEMONIC || "your mnemonic"
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "Your etherscan API key"
const BSCSCAN_API_KEY = process.env.BSCSCAN_API_KEY || "Your etherscan API key"
const MUMBAI_RPC_URL = process.env.MUMBAI_RPC_URL
// optional
const PRIVATE_KEY = process.env.PRIVATE_KEY || "your private key"
const PRIVATE_KEY_2 = process.env.PRIVATE_KEY_2 || "your private key"
module.exports = {
  defaultNetwork: "mumbai",
  networks: {
    hardhat: {
    },
    local: {
      url: 'http://127.0.0.1:8545/'
    },
    mumbai: {
      url: MUMBAI_RPC_URL,
      accounts: [PRIVATE_KEY],
      // accounts: {
      //   mnemonic: MNEMONIC,
      // },
      saveDeployments: true,
    },
    goerli: {
      url: GOERLI_RPC_URL,
      accounts: [PRIVATE_KEY],
      // accounts: {
      //   mnemonic: MNEMONIC,
      // },
      saveDeployments: true,
    },
    bsc_testnet: {
      url: BSC_TESTNET_RPC_URL,
      accounts: [PRIVATE_KEY],
      // accounts: {
      //   mnemonic: MNEMONIC,
      // },
      saveDeployments: true,
      apiKey: BSCSCAN_API_KEY
    }
  },
  solidity: "0.8.9",
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
      1: 0 // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
    },
    feeCollector: {
      default: 1
    }
  },
  etherscan: {
    api_keys: BSCSCAN_API_KEY
    // {
    // bscscan: BSCSCAN_API_KEY,
    // etherscan: ETHERSCAN_API_KEY
    // } 
  }
}

