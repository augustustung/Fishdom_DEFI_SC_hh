const { ethers } = require('hardhat');
const saveDeployments = require('../../../utils/saveDeployments');
const CompliedResolver = require('../../../artifacts/contracts/rentNFT/Resolver.sol/Resolver.json');

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(
    'Deploy wallet balance:',
    ethers.utils.formatEther(await deployer.getBalance())
  );
  console.log('Deployer wallet public key:', deployer.address);
  const Contract = await ethers.getContractFactory('ReNFT');
  const reNFT = await Contract.deploy(CompliedResolver.networks[97].address, deployer.address, deployer.address);
  const reNFTInstance = await reNFT.deployed();
  console.log(
    `SC ReNFT deployed to ${reNFTInstance.address}`
  );
  const PATH = '/rentNFT/ReNFT.sol/ReNFT.json'
  const DATA = {
    "networks": {
      "97": {
        "address": CompliedResolver.networks[97].address
      }
    }
  }
  saveDeployments(PATH, DATA);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });