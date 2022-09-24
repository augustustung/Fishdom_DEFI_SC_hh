const { ethers } = require('hardhat');
require('dotenv').config();
const CompliedFishdomMarket = require('../../artifacts/contracts/FishdomMarket.sol/FishdomMarket.json');
const CompliedFishdomNFT = require('../../artifacts/contracts/FishdomNFT.sol/FishdomNFT.json');
const CompliedFishdomToken = require('../../artifacts/contracts/token/FishdomToken.sol/FishdomToken.json');

async function buyMarketItem() {
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

  const contractFishdomToken = new ethers.Contract(
    CompliedFishdomToken.networks[97].address,
    CompliedFishdomToken.abi,
    signer
  )

  let approveTx = await contractFishdomToken.approve(
    CompliedFishdomMarket.networks[97].address,
    "10000000000000"
  );
  await approveTx.wait(1);
  let buyTx = await contractMarket.buyMarketItem(1);
  await buyTx.wait(1);

  const balanceOf = await contractNFT.balanceOf(signer.address);
  console.log(balanceOf);
}

buyMarketItem()
  .then(() => {
    process.exit(0);
  })
  .catch(err => {
    console.log('error', err);
    process.exit(1);
  });