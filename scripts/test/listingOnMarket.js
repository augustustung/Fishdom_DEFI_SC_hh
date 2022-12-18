const { ethers } = require('hardhat');
require('dotenv').config();
const CompliedFishdomMarket = require('../../artifacts/contracts/FishdomMarket.sol/FishdomMarket.json');
const CompliedFishdomNFT = require('../../artifacts/contracts/FishdomNFT.sol/FishdomNFT.json');

function randomIntFromInterval(min, max) { // min and max included 
  return Math.floor(Math.random() * (max - min + 1) + min)
}

async function listingOnMarket() {
  const [signer] = await ethers.getSigners();
  console.log(
    'Signer wallet balance:',
    ethers.utils.formatEther(await signer.getBalance())
  );
  console.log('Signer wallet public key:', signer.address);
  const contractMarket = new ethers.Contract(
    CompliedFishdomMarket.networks[97].address,
    CompliedFishdomMarket.abi,
    signer
  );

  const contractNFT = new ethers.Contract(
    CompliedFishdomNFT.networks[97].address,
    CompliedFishdomNFT.abi,
    signer
  );
  const LAST_NFT_ID = 20; // LATEST ROI
  for (let i = LAST_NFT_ID; i <= LAST_NFT_ID + 5; i++) {
    let randomPrice = ethers.utils.parseEther(randomIntFromInterval(1, 100).toString());
    let approveTx = await contractNFT.approve(CompliedFishdomMarket.networks[97].address, i);
    await approveTx.wait(1);
    let listingOnMarketTx = await contractMarket.createMarketItem(i, randomPrice);
    await listingOnMarketTx.wait(1);
  }
  // call api after mint
}

listingOnMarket()
  .then(() => {
    process.exit(0);
  })
  .catch(err => {
    console.log('error', err);
    process.exit(1);
  });