// import hre from 'hardhat';
import { ethers } from 'hardhat';
import * as dotenv from 'dotenv';
import { getAddress } from 'ethers';

// load env vars
dotenv.config();
const { UP_ADDR, PRIVATE_KEY } = process.env;

async function main() {
  // const Minter = await ethers.getContractFactory("GenesisMinter")
  // const minter = await Minter.deploy(ethers.getAddress(UP_ADDR as string))
  // const minterAddress = await minter.getAddress()
  // console.log('Minter Address', minterAddress)
  console.log('x');

  const TokenUtilsFactory = await ethers.getContractFactory('TokenUtils');

  console.log('y');
  const TokenUtils = await TokenUtilsFactory.deploy();
  console.log('z');
  const tokenUtils = await TokenUtils.waitForDeployment();
  console.log('p');
  const PassAddress = await tokenUtils.getAddress();
  console.log(`Library address: ${PassAddress}`);

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
