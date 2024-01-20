import { expect } from "chai";
import { ethers } from "hardhat";
import short from 'short-uuid';
import { hexValue, hexZeroPad, hexlify } from "@ethersproject/bytes";

import { ERC725 } from '@erc725/erc725.js';
import { EventLog, toUtf8Bytes } from "ethers";

describe("AssetPlaceholder", function () {
  const options = {
    libraries: {}
  };

  beforeEach(async () => {
    const TokenUtils = await ethers.getContractFactory("TokenUtils");
    const tokenUtils = await TokenUtils.deploy();

    (options.libraries as any).TokenUtils = await tokenUtils.getAddress();
  });

  describe("Deployment", function () {
    it('should read token metadata from parent collection', async function () {
      const [owner, registry, userAccount] = await ethers.getSigners();

      const AssetPlaceholder = await ethers.getContractFactory("AssetPlaceholder", options);
      const placeholderContract = await AssetPlaceholder.deploy('PhygitalAssetPlaceholder', 'PAP', owner, registry.address);
      const placeholder = await placeholderContract.getAddress();

      const IdentifiablePhygitalAsset = await ethers.getContractFactory("IdentifiablePhygitalAsset", options);
      const assetContract = await IdentifiablePhygitalAsset.deploy('IdentifiablePhygitalAsset', 'IPA', owner, 1, placeholder);
      const assetAddress = await assetContract.getAddress();
      
      const variantId = hexZeroPad(hexValue(29), 12),
        metadata = hexlify(toUtf8Bytes('https')),
        startAt = Math.floor((Date.now() - 1 * 24 * 60 * 60)/1000),
        duration = Math.floor(7 * 24 * 60 * 60/1000);

      const registerTxn = await assetContract.registerVariant(variantId, metadata);
      const registerColTxn = await placeholderContract.registerCollection(assetAddress, startAt, duration, false);

      await registerTxn.wait();
      await registerColTxn.wait();

      const mintTxn = await placeholderContract.mint(userAccount.address, assetAddress, variantId, true, '0x', false);
      const txnReciept = await mintTxn.wait();

      const transferEvent = txnReciept?.logs.filter((log: any) => log.eventName === 'Transfer')[0] as EventLog;
      const tokenId = transferEvent?.args[3];

      const tokenMetadataKey = ERC725.encodeKeyName('LSP8MetadataTokenURI:<bytes32>', [tokenId]);

      expect(await placeholderContract.getData(tokenMetadataKey)).to.equal(metadata);
    });

    it('should not mint tokens before start time', async () => {
      const [owner, registry, userAccount] = await ethers.getSigners();

      const AssetPlaceholder = await ethers.getContractFactory("AssetPlaceholder", options);
      const placeholderContract = await AssetPlaceholder.deploy('PhygitalAssetPlaceholder', 'PAP', owner, registry.address);
      const placeholder = await placeholderContract.getAddress();

      const IdentifiablePhygitalAsset = await ethers.getContractFactory("IdentifiablePhygitalAsset", options);
      const assetContract = await IdentifiablePhygitalAsset.deploy('IdentifiablePhygitalAsset', 'IPA', owner, 1, placeholder);
      const assetAddress = await assetContract.getAddress();
      
      const variantId = hexZeroPad(hexValue(29), 12),
        metadata = hexlify(toUtf8Bytes('https')),
        startAt = Math.floor((Date.now() + 1 * 24 * 60 * 60)/1000),
        duration = Math.floor(3 * 24 * 60 * 60/1000);

      const registerTxn = await assetContract.registerVariant(variantId, metadata);
      const registerColTxn = await placeholderContract.registerCollection(assetAddress, startAt, duration, false);

      await registerTxn.wait();
      await registerColTxn.wait();

      expect(placeholderContract.mint(userAccount.address, assetAddress, variantId, true, '0x', false))
        .to.be.revertedWithCustomError({ interface: AssetPlaceholder.interface }, 'MintingPeriodNotStarted');
    });

    it('should not mint tokens after end time', async () => {
      const [owner, registry, userAccount] = await ethers.getSigners();

      const AssetPlaceholder = await ethers.getContractFactory("AssetPlaceholder", options);
      const placeholderContract = await AssetPlaceholder.deploy('PhygitalAssetPlaceholder', 'PAP', owner, registry.address);
      const placeholder = await placeholderContract.getAddress();

      const IdentifiablePhygitalAsset = await ethers.getContractFactory("IdentifiablePhygitalAsset", options);
      const assetContract = await IdentifiablePhygitalAsset.deploy('IdentifiablePhygitalAsset', 'IPA', owner, 1, placeholder);
      const assetAddress = await assetContract.getAddress();
      
      const variantId = hexZeroPad(hexValue(29), 12),
        metadata = hexlify(toUtf8Bytes('https')),
        startAt = Math.floor((Date.now() - 8 * 24 * 60 * 60)/1000),
        duration = Math.floor((3 * 24 * 60 * 60)/1000)

      const registerTxn = await assetContract.registerVariant(variantId, metadata);
      const registerColTxn = await placeholderContract.registerCollection(assetAddress, startAt, duration, false);

      await registerTxn.wait();
      await registerColTxn.wait();

      expect(placeholderContract.mint(userAccount.address, assetAddress, variantId, true, '0x', false))
        .to.be.revertedWithCustomError({ interface: AssetPlaceholder.interface }, 'MintingPeriodEnded');
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
        duration = Math.floor((1 * 24 * 60 * 60)/1000);

      const registerTxn = await assetContract.registerVariant(variantId, metadata);
      const registerColTxn = await placeholderContract.registerCollection(assetAddress, startAt, duration, false);

      await registerTxn.wait();
      await registerColTxn.wait();

      expect(placeholderContract.mint(userAccount.address, assetAddress, variantId, true, '0x', false)).not.to.be.reverted;

      await placeholderContract.updateMintDuration(assetAddress, 15 * 24 * 60 * 60);

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
    });

    it('[digital] should allow to mint tokens after end time extension', async () => {
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
        duration = Math.floor((1 * 24 * 60 * 60)/1000);

      const registerTxn = await assetContract.registerVariant(variantId, metadata);
      const registerColTxn = await placeholderContract.registerCollection(assetAddress, startAt, duration, true);

      await registerTxn.wait();
      await registerColTxn.wait();

      expect(placeholderContract.mint(userAccount.address, assetAddress, variantId, true, '0x', false)).not.to.be.reverted;

      await placeholderContract.updateMintDuration(assetAddress, 15 * 24 * 60 * 60);

      const mintTxn = await placeholderContract.mint(userAccount.address, assetAddress, variantId, true, '0x', false);

      expect(mintTxn)
        .to.not.be.revertedWithCustomError({ interface: AssetPlaceholder.interface }, 'MintingPeriodEnded');

      await mintTxn.wait();

      const placeholderTokenIds = await placeholderContract.tokenIdsOf(userAccount.address);
      const tokenIds = await assetContract.tokenIdsOf(userAccount.address);

      expect(placeholderTokenIds.length).to.equal(0);
      expect(tokenIds.length).to.equal(1);
    });
  });
});
