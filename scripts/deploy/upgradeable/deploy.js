// scripts/deploy.js
const { ethers, upgrades } = require('hardhat');
const saveDeployments = require('../../../utils/saveDeployments');

async function main() {
    // deploy upgradeable contract
    const [deployer] = await ethers.getSigners();
    console.log(
        'Deploy wallet balance:',
        ethers.utils.formatEther(await deployer.getBalance())
    );
    console.log('Deployer wallet public key:', deployer.address);

    const Contract = await ethers.getContractFactory('FishdomNFT');
    const proxyContract = await upgrades.deployProxy(Contract, ['Fishdom Fish', 'FdF', 'https://mydomain.com']);
    await proxyContract.deployed();

    console.log(`OpenZeppelin Proxy deployed to ${proxyContract.address}\n\n`);
    const PATH = '/FishdomNFT.sol/FishdomNFT.json'
    const DATA = {
        "networks": {
            "80001": {
                "address": proxyContract.address
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