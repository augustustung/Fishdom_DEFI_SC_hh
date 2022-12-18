const { ethers } = require('hardhat');
require('dotenv').config();
const CompliedFishdomNFT = require('../../artifacts/contracts/FishdomNFT.sol/FishdomNFT.json');

const TO = "0x06c5b74c3A0F903a02c46F27Ca42D34810E220A2"

async function transferNFT() {
  const [signer] = await ethers.getSigners();
  console.log(
    'Signer wallet balance:',
    ethers.utils.formatEther(await signer.getBalance())
  );
  console.log('Signer wallet public key:', signer.address);

  const contractNFT = new ethers.Contract(
    CompliedFishdomNFT.networks[97].address,
    CompliedFishdomNFT.abi,
    signer
  );

  // let transferTx = await contractNFT.transferFrom(signer.address, TO, 16);
  // await transferTx.wait(1);
  // console.log(transferTx)
  for (let i = 6; i <= 20; i++) {
    console.log(i, await contractNFT.ownerOf(i))
  }


  // call api after mint

}

transferNFT()
  .then(() => {
    process.exit(0);
  })
  .catch(err => {
    console.log('error', err);
    process.exit(1);
  });