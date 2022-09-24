const { ethers } = require('hardhat');
require('dotenv').config();
const CompliedFishdomMarket = require('../../artifacts/contracts/FishdomMarket.sol/FishdomMarket.json');
const CompliedFishdomNFT = require('../../artifacts/contracts/FishdomNFT.sol/FishdomNFT.json');

async function listingOnMarket() {
  const [signer] = await ethers.getSigners();
  console.log(
    'Signer wallet balance:',
    ethers.utils.formatEther(await signer.getBalance())
  );
  console.log('Signer wallet public key:', signer.address);
  const contractMarket = new ethers.Contract(
    CompliedFishdomMarket.network[97].address,
    CompliedFishdomMarket.abi,
    signer
  );

  const contractNFT = new ethers.Contract(
    CompliedFishdomNFT.network[97].address,
    CompliedFishdomNFT.abi,
    signer
  );

  for (let i = 1; i <= 5; i++) {
    let randomPrice = ethers.utils.parseEther("0.00001");
    let approveTx = await contractNFT.approve(CompliedFishdomMarket.network[97].address, i);
    await approveTx.wait(1);
    let listingOnMarketTx = await contractMarket.createMarketItem(i, randomPrice);
    await listingOnMarketTx.wait(1);
  }
}

listingOnMarket()
  .then(() => {
    process.exit(0);
  })
  .catch(err => {
    console.log('error', err);
    process.exit(1);
  });