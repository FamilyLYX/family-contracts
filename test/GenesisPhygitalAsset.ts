import { expect } from "chai";
import { ethers } from "hardhat";
import short from 'short-uuid';
import { hexValue, hexZeroPad, hexlify } from "@ethersproject/bytes";

import { ERC725 } from '@erc725/erc725.js';
import { EventLog, toUtf8Bytes } from "ethers";

describe("GenesisPhygitalAsset", function () {
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

      const GenesisPhygitalAsset = await ethers.getContractFactory("GenesisPhygitalAsset", options);
      const assetContract = await GenesisPhygitalAsset.deploy('IdentifiablePhygitalAsset', 'IPA', owner);
      const assetAddress = await assetContract.getAddress();
      
      const variantId = hexZeroPad(hexValue(29), 12),
        metadata = hexlify(toUtf8Bytes('https')),
        startAt = Math.floor((Date.now() - 1 * 24 * 60 * 60)/1000),
        duration = Math.floor(7 * 24 * 60 * 60/1000);

      const registerTxn = await assetContract.registerVariant(variantId, metadata);

      await registerTxn.wait();

      const mintTxn = await assetContract.mint(userAccount.address, variantId, 1, true, '0x');
      const txnReciept = await mintTxn.wait();

      const transferEvent = txnReciept?.logs.filter((log: any) => log.eventName === 'Transfer')[0] as EventLog;
      const tokenId = transferEvent?.args[3];

      console.log(await assetContract.getData(ERC725.encodeKeyName('LSP4TokenType')))
      console.log(await assetContract.getData(ERC725.encodeKeyName('LSP8TokenIdFormat')));
    });
  });
});
