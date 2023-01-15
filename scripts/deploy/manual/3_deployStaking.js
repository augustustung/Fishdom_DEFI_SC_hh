const { ethers } = require('hardhat');
const saveDeployments = require('../../../utils/saveDeployments');
const CompliedFishdomToken = require('../../../artifacts/contracts/token/FishdomToken.sol/FishdomToken.json');

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(
    'Deploy wallet balance:',
    ethers.utils.formatEther(await deployer.getBalance())
  );
  console.log('Deployer wallet public key:', deployer.address);
  const Contract = await ethers.getContractFactory('FishdomStaking');
  const FishdomStaking = await Contract.deploy(CompliedFishdomToken.networks["80001"].address);
  const instance = await FishdomStaking.deployed();
  await instance.initialize();
  console.log(
    `SC FishdomStaking deployed to ${FishdomStaking.address}`
  );

  const PATH = '/FishdomStaking.sol/FishdomStaking.json'
  const DATA = {
    "networks": {
      "80001": {
        "address": FishdomStaking.address
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