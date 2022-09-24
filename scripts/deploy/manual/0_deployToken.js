const { ethers } = require('hardhat');
const saveDeployments = require('../../../utils/saveDeployments');

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(
    'Deploy wallet balance:',
    ethers.utils.formatEther(await deployer.getBalance())
  );
  console.log('Deployer wallet public key:', deployer.address);
  const INITIAL_SUPPLY = 1000000000;
  const Contract = await ethers.getContractFactory('FishdomToken');
  const FishdomToken = await Contract.deploy("Fishdom Token", "FdT", INITIAL_SUPPLY);

  await FishdomToken.deployed();
  console.log(
    `SC FishdomToken deployed to ${FishdomToken.address}`
  );
  const PATH = '/token/FishdomToken.sol/FishdomToken.json'
  const DATA = {
    "network": {
      "97": {
        "address": FishdomToken.address
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