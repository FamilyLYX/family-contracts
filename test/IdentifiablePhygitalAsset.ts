import { expect } from "chai";
import { ethers } from "hardhat";
import { hexValue, hexZeroPad, hexlify } from "@ethersproject/bytes";

import { ERC725 } from '@erc725/erc725.js';
import { EventLog, toUtf8Bytes } from "ethers";

// keccak256('LSP4TokenName')
const _LSP4_TOKEN_NAME_KEY = '0xdeba1e292f8ba88238e10ab3c7f88bd4be4fac56cad5194b6ecceaf653468af1';

// keccak256('LSP4TokenSymbol')
const _LSP4_TOKEN_SYMBOL_KEY = '0x2f0a68ab07768e01943a599e73362a0e17a63a72e94dd2e384d2c1d4db932756';

describe("IdentifiablePhysicalAsset", function () {
  const options = {
    libraries: {}
  };

  beforeEach(async () => {
    const TokenUtils = await ethers.getContractFactory("TokenUtils");
    const tokenUtils = await TokenUtils.deploy();

    (options.libraries as any).TokenUtils = await tokenUtils.getAddress();
  });

  describe("Deployment", function () {
    it("Should set the right properties", async function () {
      // Contracts are deployed using the first signer/account by default
      const [owner, placeholder, userAccount] = await ethers.getSigners();

      const IdentifiablePhygitalAsset = await ethers.getContractFactory("IdentifiablePhygitalAsset", options);
      const assetContract = await IdentifiablePhygitalAsset.deploy('IdentifiablePhygitalAsset', 'IPA', owner, 1, placeholder.address);
      
      const variantId = hexZeroPad(hexValue(29), 12),
        assetId = hexZeroPad(hexValue(11), 12),
        metadata = hexlify(toUtf8Bytes('https'));

      // expect(await assetContract.supportsInterface('0x30dc5278')).to.be.true;

      await assetContract.registerVariant(variantId, metadata);
      const mintTxn = await assetContract.connect(placeholder)
        .mint(userAccount.address, assetId, variantId, true, '0x');

      const txnReciept = await mintTxn.wait();
      const transferEvent = txnReciept?.logs.filter((log: any) => log.eventName === 'Transfer')[0] as EventLog;

      const tokenId = transferEvent?.args[3];

      const tokenMetadataKey = ERC725.encodeKeyName('LSP8MetadataTokenURI:<bytes32>', [tokenId]);

      expect(await assetContract.getData(_LSP4_TOKEN_NAME_KEY)).to.equal(hexlify(toUtf8Bytes('IdentifiablePhygitalAsset')));
      expect(await assetContract.getData(_LSP4_TOKEN_SYMBOL_KEY)).to.equal(hexlify(toUtf8Bytes('IPA')));
      expect(await assetContract.getData(tokenMetadataKey)).to.equal(metadata);
    });

    it("Should not mint the same asset twice", async function () {
      const [owner, placeholder, userAccount] = await ethers.getSigners();

      const IdentifiablePhysicalAsset = await ethers.getContractFactory("IdentifiablePhygitalAsset", options);
      const assetContract = await IdentifiablePhysicalAsset.deploy('IdentifiablePhygitalAsset', 'IPA', owner, 1, placeholder.address);

      const variantId = hexZeroPad(hexValue(29), 12),
        assetId = hexZeroPad(hexValue(11), 12),
        secondAssetid = hexZeroPad(hexValue(12), 12),
        metadata = hexlify(toUtf8Bytes('https'));

      await assetContract.registerVariant(variantId, metadata);
      
      await assetContract.connect(placeholder)
        .mint(userAccount.address, assetId, variantId, true, '0x');

      expect(assetContract.connect(placeholder)
        .mint(userAccount.address, assetId, variantId, true, '0x'))
        .to.be.revertedWithCustomError({ interface: IdentifiablePhysicalAsset.interface }, 'AssetAlreadyRegistered');

      expect(assetContract.connect(placeholder)
        .mint(userAccount.address, secondAssetid, variantId, true, '0x'))
        .to.be.revertedWithCustomError({ interface: IdentifiablePhysicalAsset.interface }, 'LSP8CappedSupplyCannotMintOverCap');
    });
  });
});
