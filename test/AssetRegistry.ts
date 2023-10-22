import { expect } from "chai";
import { ethers } from "hardhat";
import short from 'short-uuid';
import { hexValue, hexZeroPad, hexlify } from "@ethersproject/bytes";

import { toUtf8Bytes } from "ethers";

describe("AssetRegistry", function () {
  const options = {
    libraries: {}
  };

  beforeEach(async () => {
    const TokenUtils = await ethers.getContractFactory("TokenUtils");
    const tokenUtils = await TokenUtils.deploy();

    (options.libraries as any).TokenUtils = await tokenUtils.getAddress();
  });
  
  describe("Deployment", function () {
    it('should allow registration and query of registars and identifiers', async () => {
      const assetUid = short.generate();
      const assetIdentifier = ethers.keccak256(toUtf8Bytes(assetUid));
      const [owner, userAccount] = await ethers.getSigners();

      const AssetRegistry = await ethers.getContractFactory("AssetRegistry");
      const registryContract = await AssetRegistry.deploy(owner);
      const registryAddr = await registryContract.getAddress();

      const AssetPlaceholder = await ethers.getContractFactory("AssetPlaceholder", options);
      const placeholderContract = await AssetPlaceholder.deploy('PhygitalAssetPlaceholder', 'PAP', owner, registryAddr);
      const placeholderAddr = await placeholderContract.getAddress();

      const IdentifiablePhygitalAsset = await ethers.getContractFactory("IdentifiablePhygitalAsset", options);
      const assetContract = await IdentifiablePhygitalAsset.deploy('IdentifiablePhygitalAsset', 'IPA', owner, 1, placeholderAddr);
      const assetAddress = await assetContract.getAddress();

      // Register placeholder as registar on asset registry
      await (await registryContract.addAddress(placeholderAddr)).wait();
      await (await registryContract.addToPool([assetIdentifier], assetAddress)).wait();

      expect(await registryContract.totalSupply()).to.equal(1);
      expect(await registryContract.identifierAt(0)).to.equal(assetIdentifier);

      expect(await registryContract.totalRegistars()).to.equal(1);
      expect(await registryContract.registarAt(0)).to.equal(placeholderAddr);
    });

    it('should allow to mint tokens after end time extension', async () => {
      const assetUid = short.generate();
      const assetIdentifier = ethers.keccak256(toUtf8Bytes(assetUid));
      const [owner, userAccount] = await ethers.getSigners();

      const AssetRegistry = await ethers.getContractFactory("AssetRegistry");
      const registryContract = await AssetRegistry.deploy(owner);
      const registryAddr = await registryContract.getAddress();

      const AssetPlaceholder = await ethers.getContractFactory("AssetPlaceholder", options);
      const placeholderContract = await AssetPlaceholder.deploy('PhygitalAssetPlaceholder', 'PAP', owner, registryAddr);
      const placeholderAddr = await placeholderContract.getAddress();

      const IdentifiablePhygitalAsset = await ethers.getContractFactory("IdentifiablePhygitalAsset", options);
      const assetContract = await IdentifiablePhygitalAsset.deploy('IdentifiablePhygitalAsset', 'IPA', owner, 1, placeholderAddr);
      const assetAddress = await assetContract.getAddress();

      // Register placeholder as registar on asset registry
      await (await registryContract.addAddress(placeholderAddr)).wait();
      await (await registryContract.addToPool([assetIdentifier], assetAddress)).wait();
      
      const variantId = hexZeroPad(hexValue(29), 12),
        metadata = hexlify(toUtf8Bytes('https')),
        startAt = Math.floor((Date.now() - 8 * 24 * 60 * 60)/1000),
        duration = Math.floor(30 * 24 * 60 * 60 / 1000)

      const registerTxn = await assetContract.registerVariant(variantId, metadata);
      const registerColTxn = await placeholderContract.registerCollection(assetAddress, startAt, duration);

      await registerTxn.wait();
      await registerColTxn.wait();

      const mintTxn = await placeholderContract.mint(userAccount.address, assetAddress, variantId, true, '0x', false);

      expect(mintTxn)
        .to.not.be.revertedWithCustomError({ interface: AssetPlaceholder.interface }, 'MintingPeriodEnded');

      await mintTxn.wait();

      const [tokenId] = await placeholderContract.tokenIdsOf(userAccount.address);

      const freezeTxn = await placeholderContract.freeze(tokenId);
      freezeTxn.wait();

      const signature = await owner.signMessage(assetUid);
      const tokenRegisterTxn = await placeholderContract.connect(userAccount).register(assetUid, signature, tokenId);

      await tokenRegisterTxn.wait();

      const [assetTokenId] = await assetContract.tokenIdsOf(userAccount.address);
      const [collection, registryTokenId] = await registryContract.checkIdentifier(assetIdentifier);

      expect(collection).to.equal(assetAddress);
      expect(registryTokenId).to.equal(assetTokenId);
      expect(await assetContract.balanceOf(userAccount.address)).to.equal(1);
      expect(tokenId).to.equal(assetTokenId);
    });
  });
});
