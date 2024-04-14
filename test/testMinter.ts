import { expect } from "chai";
import { ethers } from "hardhat";
import { describe, it } from "mocha";


const setupAssets = async () => {

    const [userAccount, secondAccount] = await ethers.getSigners();

    const TokenUtils = await ethers.getContractFactory('TokenUtils');
    const tokenUtils = await TokenUtils.deploy();
    const tokenUtilsAddress = await tokenUtils.getAddress()
    console.log(tokenUtilsAddress)

    const Minter = await ethers.getContractFactory("GenesisMinter")
    const minter = await Minter.deploy(ethers.getAddress(userAccount.address as string))
    const minterAddress = await minter.getAddress()
    console.log('Minter Address', minterAddress)
    console.log('x');
    const genesisPerk = await ethers.getContractFactory('LSP7Perk');

    console.log('y');
    const Token = await genesisPerk.deploy('Genesis Perk LSP7', 'GEN', ethers.getAddress(userAccount.address as string));
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
    const genesisPhygitalAsset = await GenesisPhygitalAsset.deploy("Genesis", "GEN", userAccount.address as string, minterAddress as string)
    const GenesisPhygitalAssetAddress = await genesisPhygitalAsset.getAddress()
    // await genesisPhygitalAsset.registerVariant(  )
}

describe.skip('Minter with LSPs', async function () {
    it("Should set the right properties", async function () {


        const [userAccount, secondAccount] = await ethers.getSigners();
        const options: any = {
            libraries: {}
        };

        beforeEach(async () => {
            const TokenUtils = await ethers.getContractFactory("TokenUtils");
            const tokenUtils = await TokenUtils.deploy();

            (options.libraries as any).TokenUtils = await tokenUtils.getAddress();
        });

        const TokenUtils = await ethers.getContractFactory('TokenUtils');
        const tokenUtils = await TokenUtils.deploy();
        const tokenUtilsAddress = await tokenUtils.getAddress()

        const Minter = await ethers.getContractFactory("GenesisMinter")
        const minter = await Minter.deploy(ethers.getAddress(userAccount.address as string))
        const minterAddress = await minter.getAddress()


        const genesisPerk = await ethers.getContractFactory('LSP7Perk');

        const Token = await genesisPerk.deploy('Genesis Perk LSP7', 'GEN', ethers.getAddress(userAccount.address as string));
        const token = await Token.waitForDeployment();
        const GenesisPerkAddress = await token.getAddress();
        const GenesisPhygitalAsset = await ethers.getContractFactory("GenesisPhygitalAsset", {
            libraries: {
                TokenUtils: tokenUtilsAddress,
            },
        })
        const genesisPhygitalAsset = await GenesisPhygitalAsset.deploy("Genesis", "GEN", userAccount.address as string, minterAddress as string)
        const GenesisPhygitalAssetAddress = await genesisPhygitalAsset.getAddress()
        await genesisPhygitalAsset.registerVariant('0x000000000000000000000001', '0x00006f357c6a00202d848f15286d127a488de9e9d7a5cbbcb24a50cba366a76c64aad264d40ece4f697066733a2f2f516d6556614a364c5231585332616b55775a4377536142354c3564766e3969787347457a53475176327068737738')
        const txn = await minter.setCollections(GenesisPhygitalAssetAddress, GenesisPerkAddress)
        const reciept = await txn.wait()
        const mintTxn = await minter.mintGenesis(secondAccount.address as string, '0x000000000000000000000001', true, '0x000000000000000000000001', 1, 'user-123')
        const mintReciept = await mintTxn.wait()
        console.log('minted', mintReciept)
        expect(reciept?.status == 1);
    })
})