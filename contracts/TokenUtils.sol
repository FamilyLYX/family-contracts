// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./constants.sol";

struct TokenId {
  bytes6 collectionId;
  bytes12 variantId;
  bytes12 assetId;
}

library TokenUtils {
  function collectionId (address collection) public pure returns (bytes6) {
    return bytes6(keccak256(abi.encodePacked(collection)));
  }

  // 0x798c6047767c 0000 00000000000000000000001d 000000000000000000000001
  function getTokenId (address collection, bytes12 variantId, bytes12 assetId) public pure returns (bytes32) {
    return bytes32(
      bytes.concat(
        collectionId(collection),
        bytes2(0),
        variantId,
        assetId
      )
    );
  }

  function getTokenId (TokenId memory _tokenId) public pure returns (bytes32) {
    return bytes32(
      bytes.concat(
        _tokenId.collectionId,
        bytes2(0),
        _tokenId.variantId,
        _tokenId.assetId
      )
    );
  }

  function parseTokenId (bytes32 tokenId) public pure returns (TokenId memory tokenIdInstance) {
    tokenIdInstance.collectionId = bytes6(tokenId);
    tokenIdInstance.variantId = bytes12(tokenId << 8 * (6 + 2));
    tokenIdInstance.assetId = bytes12(tokenId << 8 * (6 + 2 + 12));
  }

  function parseDataKey (bytes32 dataKey) public pure returns (TokenId memory tokenIdInstance) {
    tokenIdInstance.collectionId = bytes6(dataKey << 8 * (10 + 2));
    tokenIdInstance.variantId = bytes12(dataKey << 8 * (10 + 2 + 6 + 2));
    tokenIdInstance.assetId = bytes12(0);
  }

  // 0x1339e76a390b7b9ec901 0000 00000000000000000000001d 0000000000000000
  function getDataKey (TokenId memory tokenId) public pure returns (bytes32) {
    return bytes32(
      bytes.concat(
        _LSP8_TOKEN_METADATA_KEY_PREFIX,
        bytes2(0),
        tokenId.collectionId,
        bytes2(0),
        tokenId.variantId
      )
    );
  }

  function getDataKey (address collection, bytes12 variantId) public pure returns (bytes32) {
    return bytes32(
      bytes.concat(
        _LSP8_TOKEN_METADATA_KEY_PREFIX,
        bytes2(0),
        collectionId(collection),
        bytes2(0),
        variantId
      )
    );
  }
}
