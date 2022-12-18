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
  const Contract = await ethers.getContractFactory('Resolver');
  const Resolver = await Contract.deploy(deployer.address);
  const ResolverInstance = await Resolver.deployed();
  console.log(
    `SC Resolver deployed to ${Resolver.address}`
  );
  await ResolverInstance.setPaymentToken("FdT", CompliedFishdomToken.networks[97].address);
  const PATH = '/rentNFT/Resolver.sol/Resolver.json'
  const DATA = {
    "networks": {
      "97": {
        "address": Resolver.address
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