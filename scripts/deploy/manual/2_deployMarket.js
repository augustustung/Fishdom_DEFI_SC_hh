const { ethers } = require('hardhat');
const saveDeployments = require('../../../utils/saveDeployments');
const CompliedFishdomToken = require('../../../artifacts/contracts/token/FishdomToken.sol/FishdomToken.json');
const CompliedFishdomNFT = require('../../../artifacts/contracts/FishdomNFT.sol/FishdomNFT.json');

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(
    'Deploy wallet balance:',
    ethers.utils.formatEther(await deployer.getBalance())
  );
  console.log('Deployer wallet public key:', deployer.address);
  const Contract = await ethers.getContractFactory('FishdomMarket');
  const FishdomMarket = await Contract.deploy(CompliedFishdomToken.network[97].address, CompliedFishdomNFT.network[97].address);
  await FishdomMarket.deployed();
  console.log(
    `SC FishdomToken deployed to ${FishdomMarket.address}`
  );

  const PATH = '/FishdomMarket.sol/FishdomMarket.json'
  const DATA = {
    "networks": {
      "97": {
        "address": FishdomMarket.address
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