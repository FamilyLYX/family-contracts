// import hre from 'hardhat';
import { ethers } from "hardhat";
import * as dotenv from 'dotenv';

// load env vars
dotenv.config();
const { UP_ADDR, PRIVATE_KEY } = process.env;

async function main() {
    const TokenUtils = await ethers.getContractFactory('TokenUtils');
    const tokenUtils = await TokenUtils.deploy();
    const tokenUtilsAddress = await tokenUtils.getAddress()
    console.log(tokenUtilsAddress)

    // const Minter = await ethers.getContractFactory("GenesisMinter")
    // const minter = await Minter.deploy(ethers.getAddress(UP_ADDR as string))
    // const minterAddress = await minter.getAddress()
    // console.log('Minter Address', minterAddress)
    console.log('x');
    const genesisPerk = await ethers.getContractFactory('GenesisPerk');

    console.log('y');
    const Token = await genesisPerk.deploy('Test Perk', 'PERK', ethers.getAddress(UP_ADDR as string));
    console.log('z');
    const token = await Token.waitForDeployment();
    console.log('p');
    const GenesisPerkAddress = await token.getAddress();
    console.log(`Token address: ${GenesisPerkAddress}`);


    console.log("Deploying asset.. ")

    const GenesisPhygitalAsset = await ethers.getContractFactory("GenesisPhygitalAsset", {
        libraries: {
            TokenUtils: tokenUtilsAddress,
        },
    })
    const genesisPhygitalAsset = await GenesisPhygitalAsset.deploy("TEST", "TST", UP_ADDR as string)
    const GenesisPhygitalAssetAddress = await genesisPhygitalAsset.getAddress()
    // await genesisPhygitalAsset.registerVariant('0x000000000000000000000001', '0x00006f357c6a00202d848f15286d127a488de9e9d7a5cbbcb24a50cba366a76c64aad264d40ece4f697066733a2f2f516d6556614a364c5231585332616b55775a4377536142354c3564766e3969787347457a53475176327068737738')
    console.log("Deployed Collection To ", GenesisPhygitalAssetAddress)
    // await minter.setCollections(GenesisPhygitalAssetAddress, GenesisPerkAddress)
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
