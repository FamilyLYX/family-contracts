import { expect } from "chai";
import { ethers } from "hardhat";
import short from 'short-uuid';

import { toUtf8Bytes } from "ethers";
import { arrayify, hexConcat, hexValue, hexZeroPad, hexlify } from "@ethersproject/bytes";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

const FULL_PERMISSIONS = '0x00000000000000000000000000000000000000000000000000000000003fff7f';

async function setupAssets (signer: SignerWithAddress, owner: string) {
  const assetUid = short.generate();
  const assetIdentifier = ethers.keccak256(toUtf8Bytes(assetUid));

  const TokenUtils = await ethers.getContractFactory('TokenUtils');
  const tokenUtils = await TokenUtils.deploy();
  const tokenUtilsAddress = await tokenUtils.getAddress();
  const factoryOptions = {
    libraries: {
      TokenUtils: tokenUtilsAddress
    }
  };

  const AssetRegistry = await ethers.getContractFactory("AssetRegistry");
  const registryContract = await AssetRegistry.connect(signer).deploy(signer.address);
  const registryAddr = await registryContract.getAddress();

  const AssetPlaceholder = await ethers.getContractFactory("AssetPlaceholder", factoryOptions);
  const placeholderContract = await AssetPlaceholder.connect(signer).deploy('PhygitalAssetPlaceholder', 'PAP', signer.address, registryAddr);
  const placeholderAddr = await placeholderContract.getAddress();

  const IdentifiablePhygitalAsset = await ethers.getContractFactory("IdentifiablePhygitalAsset", factoryOptions);
  const assetContract = await IdentifiablePhygitalAsset.connect(signer).deploy('IdentifiablePhygitalAsset', 'IPA', signer.address, 1, placeholderAddr);
  const assetAddress = await assetContract.getAddress();

  // Register placeholder as registar on asset registry
  await (await registryContract.connect(signer).addAddress(placeholderAddr)).wait();
  await (await registryContract.connect(signer).addToPool([assetIdentifier], assetAddress)).wait();
  
  const variantId = hexZeroPad(hexValue(29), 12),
    metadata = hexlify(toUtf8Bytes('https')),
    startAt = Math.floor((Date.now() -  8 * 24 * 60 * 60)/1000),
    duration = Math.floor(30 * 24 * 60 * 60/1000)

  const registerTxn = await assetContract.connect(signer).registerVariant(variantId, metadata);
  const registerColTxn = await placeholderContract.connect(signer).registerCollection(assetAddress, startAt, duration, false);

  await registerTxn.wait();
  await registerColTxn.wait();

  await assetContract.transferOwnership(owner);
  await placeholderContract.transferOwnership(owner);

  return {
    registry: {
      address: registryAddr,
      contract: registryContract
    },
    placeholder: {
      address: placeholderAddr,
      contract: placeholderContract
    },
    asset: {
      address: assetAddress,
      contract: assetContract
    },
    contracts: {
      AssetRegistry,
      AssetPlaceholder,
      IdentifiablePhygitalAsset
    },
    meta: {
      variantId
    }
  }
}

async function setupProfile (signer: SignerWithAddress) {
  const KeyManager = await ethers.getContractFactory("CustomKeyManager");
  const keyManager = await KeyManager.connect(signer).deploy(signer.address);
  const keyMgrAddress = await keyManager.getAddress();

  const UniversalProfile = await ethers.getContractFactory("CustomUniversalProfule");
  const profile = await UniversalProfile.connect(signer).deploy(signer.address);
  const profileAddr = await profile.getAddress();

  (await profile.connect(signer).setData(
    `0x4b80742de2bf82acb3630000${signer.address.slice(2)}`,
    FULL_PERMISSIONS
  )).wait();

  await keyManager.connect(signer).updateTarget(profileAddr);
  await profile.connect(signer).transferOwnership(keyMgrAddress);
  await keyManager.connect(signer).acceptOwnership(profileAddr);

  return {
    keyManager: {
      address: keyMgrAddress,
      contract: keyManager
    },
    profile: {
      address: profileAddr,
      contract: profile
    },
    contracts: {
      UniversalProfile,
      KeyManager
    }
  }
}

describe("OrderExtension", function () {
  describe("Place order", function () {
    it('should not allow to place order if block has already been confirmed', async () => {
      const assetUid = short.generate();
      const assetIdentifier = ethers.keccak256(toUtf8Bytes(assetUid));
      const [owner, userAccount] = await ethers.getSigners();
      const { profile, keyManager } = await setupProfile(owner);
      const { placeholder, asset, meta } = await setupAssets(owner, profile.address);
      
      expect(await placeholder.contract.owner()).to.equal(profile.address);
      expect(await asset.contract.owner()).to.equal(profile.address);
      expect(await profile.contract.owner()).to.equal(keyManager.address);
      expect(await keyManager.contract.getTarget()).to.equal(profile.address);

      const OrderExtension = await ethers.getContractFactory("OrderExtension");
      const extension = await OrderExtension.deploy(profile.address);
      const extensionAddress = await extension.getAddress();

      await profile.contract.setData(`0x4b80742de2bf82acb3630000${extensionAddress.slice(2)}`, FULL_PERMISSIONS)

      const extensionDataKey = hexConcat([
        '0xcee78b4094da860110960000',
        extension.placeOrder.fragment.selector,
        hexZeroPad(hexValue(0), 16)
      ]);
      await profile.contract.setData(extensionDataKey, extensionAddress);

      expect(await profile.contract.getData(`0x4b80742de2bf82acb3630000${extensionAddress.slice(2)}`))
        .to.equal(FULL_PERMISSIONS);

      const mintCalldata = placeholder.contract.interface.encodeFunctionData(
        'mint',
        [userAccount.address, asset.address, meta.variantId, true, '0x', false]
      );
      const blockNumber = await ethers.provider.getBlockNumber() - 1;
      const value = ethers.parseEther('1');

      const orderHash = ethers.keccak256(await extension.getOrderHash(
        placeholder.address,
        value,
        blockNumber,
        hexZeroPad(hexValue(1), 32),
        mintCalldata
      ));

      const signature = await owner.signMessage(arrayify(orderHash));
      const extensionCalldata = extension.interface.encodeFunctionData(
        'placeOrder',
        [placeholder.address, value, blockNumber, hexZeroPad(hexValue(1), 32), mintCalldata, signature, '123']
      );

      expect(owner.sendTransaction({
        to: profile.address,
        data: extensionCalldata,
        value: value
      })).to.be.revertedWithCustomError(extension, 'BlockAlreadyConfirmed');

      expect(await placeholder.contract.balanceOf(userAccount.address)).to.equal(0);
      expect(await ethers.provider.getBalance(profile.address)).to.equal(0);
    });

    it('should allow to place order from an EOA', async () => {
      const assetUid = short.generate();
      const assetIdentifier = ethers.keccak256(toUtf8Bytes(assetUid));
      const [owner, userAccount] = await ethers.getSigners();
      const { profile, keyManager } = await setupProfile(owner);
      const { placeholder, asset, meta } = await setupAssets(owner, profile.address);
      
      expect(await placeholder.contract.owner()).to.equal(profile.address);
      expect(await asset.contract.owner()).to.equal(profile.address);
      expect(await profile.contract.owner()).to.equal(keyManager.address);
      expect(await keyManager.contract.getTarget()).to.equal(profile.address);

      const OrderExtension = await ethers.getContractFactory("OrderExtension");
      const extension = await OrderExtension.deploy(profile.address);
      const extensionAddress = await extension.getAddress();

      await profile.contract.setData(`0x4b80742de2bf82acb3630000${extensionAddress.slice(2)}`, FULL_PERMISSIONS)

      const extensionDataKey = hexConcat([
        '0xcee78b4094da860110960000',
        extension.placeOrder.fragment.selector,
        hexZeroPad(hexValue(0), 16)
      ]);

      await profile.contract.setData(extensionDataKey, extensionAddress);

      expect(await profile.contract.getData(`0x4b80742de2bf82acb3630000${extensionAddress.slice(2)}`))
        .to.equal(FULL_PERMISSIONS);

      const mintCalldata = placeholder.contract.interface.encodeFunctionData(
        'mint',
        [userAccount.address, asset.address, meta.variantId, true, '0x', false]
      );
      const blockNumber = await ethers.provider.getBlockNumber() + 10000;
      const value = ethers.parseEther('1');

      const orderHash = ethers.keccak256(await extension.getOrderHash(
        placeholder.address,
        value,
        blockNumber,
        hexZeroPad(hexValue(1), 32),
        mintCalldata
      ));

      const signature = await owner.signMessage(arrayify(orderHash));
      const extensionCalldata = extension.interface.encodeFunctionData(
        'placeOrder',
        [placeholder.address, value, blockNumber, hexZeroPad(hexValue(1), 32), mintCalldata, signature, '123']
      );

      await owner.sendTransaction({
        to: profile.address,
        data: extensionCalldata,
        value: value
      });

      expect(await placeholder.contract.balanceOf(userAccount.address)).to.equal(1);
      expect(await ethers.provider.getBalance(profile.address)).to.equal(value);
    });

    it('should allow to place order from an UP', async () => {
      const assetUid = short.generate();
      const assetIdentifier = ethers.keccak256(toUtf8Bytes(assetUid));
      const [owner, userAccount] = await ethers.getSigners();
      const { profile, keyManager } = await setupProfile(owner);
      const { placeholder, asset, meta } = await setupAssets(owner, profile.address);

      const { profile: userProfile, keyManager: userKeyManager } = await setupProfile(userAccount);
      
      expect(await placeholder.contract.owner()).to.equal(profile.address);
      expect(await asset.contract.owner()).to.equal(profile.address);
      expect(await profile.contract.owner()).to.equal(keyManager.address);
      expect(await keyManager.contract.getTarget()).to.equal(profile.address);

      const OrderExtension = await ethers.getContractFactory("OrderExtension");
      const extension = await OrderExtension.deploy(profile.address);
      const extensionAddress = await extension.getAddress();

      await profile.contract.setData(`0x4b80742de2bf82acb3630000${extensionAddress.slice(2)}`, FULL_PERMISSIONS)

      const extensionDataKey = hexConcat([
        '0xcee78b4094da860110960000',
        extension.placeOrder.fragment.selector,
        hexZeroPad(hexValue(0), 16)
      ]);
      await profile.contract.setData(extensionDataKey, extensionAddress);

      expect(await profile.contract.getData(`0x4b80742de2bf82acb3630000${extensionAddress.slice(2)}`))
        .to.equal(FULL_PERMISSIONS);

      const mintCalldata = placeholder.contract.interface.encodeFunctionData(
        'mint',
        [userProfile.address, asset.address, meta.variantId, true, '0x', false]
      );
      const blockNumber = await ethers.provider.getBlockNumber() + 10000;
      const value = ethers.parseEther('1');

      const orderHash = ethers.keccak256(await extension.getOrderHash(
        placeholder.address,
        value,
        blockNumber,
        hexZeroPad(hexValue(1), 32),
        mintCalldata
      ));

      const signature = await owner.signMessage(arrayify(orderHash));

      const extensionCalldata = extension.interface.encodeFunctionData(
        'placeOrder',
        [placeholder.address, value, blockNumber, hexZeroPad(hexValue(1), 32), mintCalldata, signature, '123']
      );

      await userAccount.sendTransaction({
        to: userProfile.address,
        value: ethers.parseEther('2.0')
      });

      const txnReciept = await userProfile.contract
        .connect(userAccount)
        .execute(0, profile.address, value, extensionCalldata);

      // console.log(ethers.formatEther(await ethers.provider.getBalance(owner.address)));

      expect(await placeholder.contract.balanceOf(userProfile.address)).to.equal(1);
      expect(await ethers.provider.getBalance(userProfile.address)).to.equal(ethers.parseEther('1'));

      expect(await ethers.provider.getBalance(profile.address)).to.equal(value);
    });
  });
});
