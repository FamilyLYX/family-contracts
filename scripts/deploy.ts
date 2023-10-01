import hre from 'hardhat';
import { ethers } from "hardhat";
import * as dotenv from 'dotenv';

// load env vars
dotenv.config();
const { UP_ADDR, PRIVATE_KEY } = process.env;

async function main() {
  console.log('x');
  const assetPlaceholder = await ethers.getContractFactory('AssetPlaceholder');

  console.log('y');
  const Token = await assetPlaceholder.deploy('Family Orders', 'FMLY', ethers.getAddress(UP_ADDR as string), UP_ADDR as string);
  console.log('z');
  const token = await Token.waitForDeployment();
  console.log('p');
  const AssetPlaceholderAddress = await token.getAddress();
  console.log(`Token address: ${AssetPlaceholderAddress}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
.then(() => {
  console.log('deployed')
})
.catch((error) => {
  console.log(error);

  console.error(error);
  process.exitCode = 1;
});
