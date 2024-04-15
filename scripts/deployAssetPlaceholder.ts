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

  const Pass = await ethers.getContractFactory('AssetPlaceholder', {
    libraries: {
      TokenUtils: '0xD27Cf0CdA77fe169d1CBA432E1032b0b7DbF914e'
    }
  });

  console.log('y');
  const Token = await Pass.deploy(
    'Family Orders',
    'FORDER',
    getAddress(UP_ADDR as string),
    getAddress('0x1091A69Fb1d0B74aa038dea516B7c18942CCcf2d')
  );
  console.log();
  const token = await Token.waitForDeployment();
  console.log(token.deploymentTransaction);
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
