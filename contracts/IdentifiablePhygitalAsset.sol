// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {LSP8IdentifiableDigitalAsset} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8IdentifiableDigitalAsset.sol";
import {LSP8CappedSupply } from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/extensions/LSP8CappedSupply.sol";

bytes4 constant _INTERFACEID_CAPPED_LSP8 = 0x52058d8a;

bytes32 constant _DATAKEY_TOKENID_TYPE = 0x715f248956de7ce65e94d9d836bfead479f7e70d69b718d47bfe7b00e05b4fe4;
bytes32 constant _LSP4_METADATA_KEY = 0x9afb95cacc9f95858ec44aa8c3b685511002e30ae54415823f406128b85b238e;
bytes10 constant _LSP8_TOKEN_METADATA_KEY_PREFIX = 0x1339e76a390b7b9ec901;

contract IdentifiablePhygitalAsset is LSP8CappedSupply {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    
    address internal _placeholderCollection;
    EnumerableSet.Bytes32Set internal _variants;

    event Received(address, uint);
    event VariantRegistered(bytes12 variantId);
    event VariantUnregistered(bytes12 variantId);
    event AssetMinted(bytes12 indexed variantId, bytes12 indexed assetId, bytes32 indexed tokenId);

    error OnlyPlaceholderCanMint();
    
    error VariantAlreadyRegistered();
    error VariantNotRegistered();

    error AssetAlreadyRegistered();

    error AssetIdCannotBeZero();
    error VariantIdCannotBeZero();

    constructor(
        string memory name_,
        string memory symbol_,
        address newOwner_,
        uint256 maxLimit,
        address placeholderCollection
    ) LSP8CappedSupply(maxLimit) LSP8IdentifiableDigitalAsset(name_, symbol_, newOwner_) {
        _placeholderCollection = placeholderCollection;

        // Set the token id type to be bytes32
        uint tokenIdType = 4;
        _setData(_DATAKEY_TOKENID_TYPE, abi.encodePacked(tokenIdType));
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    /**
     * Mint a token for an asset of a specific variant
     *
     * @param to Address of the UP to mint token to
     * @param assetId A bytes12 long identifier for an asset
     * @param variantId A bytes12 long identifier for a variant
     * @param allowNonLSP1Recipient A bool to check if only minting should only be allowed to UPs
     * @param data arbitary data
     */
    function mint(
        address to,
        bytes12 assetId,
        bytes12 variantId,
        bool allowNonLSP1Recipient,
        bytes memory data
    ) public {
        if (msg.sender != _placeholderCollection) {
            revert OnlyPlaceholderCanMint();
        }

        if (assetId == bytes12(0)) {
            revert AssetIdCannotBeZero();
        }

        bytes32 variantDataKey = _getVariantDataKey(variantId);

        if (!_variants.contains(variantDataKey)) {
            revert VariantNotRegistered();
        }

        bytes32 tokenId = _getAssetTokenId(variantId, assetId);

        if (_exists(tokenId)) {
            revert AssetAlreadyRegistered();
        }

        _mint(to, tokenId, allowNonLSP1Recipient, data);

        emit AssetMinted(variantId, assetId, tokenId);
    }

    function registerVariant (bytes12 variantId, bytes memory metadataUrl) public onlyOwner {
        bytes32 variantDataKey = _getVariantDataKey(variantId);

        if (variantId == bytes12(0)) {
            revert VariantIdCannotBeZero();
        }

        if (_variants.contains(variantDataKey)) {
            revert VariantAlreadyRegistered();
        }

        _variants.add(variantDataKey);
        _setData(variantDataKey, metadataUrl);

        emit VariantRegistered(variantId);
    }

    function unregisterVariant (bytes12 variantId) public onlyOwner {
        bytes32 variantDataKey = _getVariantDataKey(variantId);

        if (!_variants.contains(variantDataKey)) {
            revert VariantNotRegistered();
        }

        _variants.remove(variantDataKey);

        emit VariantUnregistered(variantId);
    }

    function _getVariantDataKey (bytes12 variantId) internal pure returns (bytes32) {
        return bytes32(bytes.concat(_LSP8_TOKEN_METADATA_KEY_PREFIX, bytes2(0), variantId, bytes12(0)));
    }

    function _getAssetTokenId (bytes12 variantId, bytes12 assetId) internal pure returns (bytes32) {
        return bytes32(bytes.concat(variantId, bytes10(0), assetId));
    }

    function supportsInterface(
        bytes4 _interfaceId
    ) public view override returns (bool) {
        return
            _interfaceId == _INTERFACEID_CAPPED_LSP8 ||
            super.supportsInterface(_interfaceId);
    }
}
