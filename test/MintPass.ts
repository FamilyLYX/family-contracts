import { arrayify } from "@ethersproject/bytes";
import { expect } from "chai";
import { AbiCoder, concat, formatEther, keccak256, parseEther } from "ethers";
import { ethers } from "hardhat";
import { describe, it } from "mocha";

describe("Pass: Minting to  user", async function () {
  it("Should set the right properties", async function () {
    const [userAccount, secondAccount] = await ethers.getSigners();
    const options: any = {
      libraries: {},
    };

    const TokenUtils = await ethers.getContractFactory("TokenUtils");
    const tokenUtils = await TokenUtils.deploy();
    const tokenUtilsAddress = await tokenUtils.getAddress();

    const Minter = await ethers.getContractFactory("GenesisMinter");
    const minter = await Minter.deploy(
      ethers.getAddress(userAccount.address as string)
    );
    const minterAddress = await minter.getAddress();

    const genesisPerk = await ethers.getContractFactory("Pass");

    const Token = await genesisPerk.deploy(
      "Genesis Perk LSP7",
      "GEN",
      ethers.getAddress(userAccount.address as string),
      ethers.getAddress(userAccount.address as string),
      ethers.getAddress(userAccount.address as string)
    );

    const token = await Token.waitForDeployment();
    const blockNumber = (await ethers.provider.getBlockNumber()) + 3;
    const price = parseEther("1");
    const abiCoder = new AbiCoder();
    // const msgSenderBytes = abiCoder.encode(["address"], [userAccount.address]);
    // const priceBytes = abiCoder.encode(["uint256"], [price]);
    // const maxBlockBytes = abiCoder.encode(["uint256"], [blockNumber]);

    // Concatenate the bytes
    const concatenatedBytes = await Token.getMintHash(
      userAccount.address,
      blockNumber,
      price
    );
    const signature = await userAccount.signMessage(
      arrayify(keccak256(concatenatedBytes))
    );
    const mintTxn = await Token.mintLYX(
      signature,
      blockNumber,
      price.toString(),
      {
        value: parseEther("1"),
      }
    );

    const mintReciept = await mintTxn.wait();
    expect(mintReciept?.status == 1);
  });
});
