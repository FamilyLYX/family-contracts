// import hre from 'hardhat';
import { ethers } from 'hardhat';
import * as dotenv from 'dotenv';

// load env vars
dotenv.config();
const { UP_ADDR, PRIVATE_KEY } = process.env;

async function main() {
  // const Minter = await ethers.getContractFactory("GenesisMinter")
  // const minter = await Minter.deploy(ethers.getAddress(UP_ADDR as string))
  // const minterAddress = await minter.getAddress()
  // console.log('Minter Address', minterAddress)
  console.log('x');
  const Pass = await ethers.getContractFactory('Pass');

  console.log('y');
  const Token = await Pass.deploy(
    'HONFT PASS',
    'PASS',
    ethers.getAddress(UP_ADDR as string),
    ethers.getAddress(UP_ADDR as string),
    ethers.getAddress(UP_ADDR as string)
  );
  console.log('z');
  const token = await Token.waitForDeployment();
  console.log('p');
  const PassAddress = await token.getAddress();
  console.log(`Token address: ${PassAddress}`);

  // await minter.setCollections(GenesisPhygitalAssetAddress, GenesisPerkAddress)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => {
    console.log('deployed');
  })
  .catch((error) => {
    console.log(error);

    console.error(error);
    process.exitCode = 1;
  });
