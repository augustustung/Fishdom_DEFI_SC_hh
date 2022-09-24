const { ethers } = require('hardhat');
require('dotenv').config();
const CompliedFishdomNFT = require('../../artifacts/contracts/FishdomNFT.sol/FishdomNFT.json');

async function mintNFT() {
  const [signer] = await ethers.getSigners();
  console.log(
    'Signer wallet balance:',
    ethers.utils.formatEther(await signer.getBalance())
  );
  console.log('Signer wallet public key:', signer.address);
  const contractInstance = new ethers.Contract(
    CompliedFishdomNFT.network[97].address,
    CompliedFishdomNFT.abi,
    signer
  );
  const txMint = await contractInstance.mint(5);
  console.log('tx: \n', txMint);
  txMint.wait(1);
  const balanceOf = await contractInstance.balanceOf(signer.address);
  console.log(balanceOf);
}

mintNFT()
  .then(() => {
    process.exit(0);
  })
  .catch(err => {
    console.log('error', err);
    process.exit(1);
  });