// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "./constants.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {LSP8IdentifiableDigitalAsset} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8IdentifiableDigitalAsset.sol";
import {LSP8CappedSupply} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/extensions/LSP8CappedSupply.sol";
import {LSP8Enumerable} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/extensions/LSP8Enumerable.sol";

import {LSP8IdentifiableDigitalAssetCore} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8IdentifiableDigitalAsset.sol";

import {TokenUtils, TokenId} from "./TokenUtils.sol";

interface IAssetVariants {
    function unregisterVariant(bytes12 variantId) external;

    function registerVariant(
        bytes12 variantId,
        bytes memory metadataUrl
    ) external;

    function getAssetTokenId(
        bytes12 variantId,
        bytes12 assetId
    ) external view returns (bytes32);

    function checkVariant(bytes12 variantId) external view returns (bool);

    function mint(
        address to,
        bytes12 assetId,
        bytes12 variantId,
        bool allowNonLSP1Recipient,
        bytes memory data
    ) external;
}

uint16 constant tokenIdType = 3;

contract IdentifiablePhygitalAsset is LSP8CappedSupply, LSP8Enumerable, IAssetVariants {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    address public placeholder;
    EnumerableSet.Bytes32Set internal _variants;

    event Received(address, uint);
    event VariantRegistered(bytes12 variantId);
    event VariantUnregistered(bytes12 variantId);
    event AssetMinted(
        bytes12 indexed variantId,
        bytes12 indexed assetId,
        bytes32 indexed tokenId
    );

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
    )
        LSP8CappedSupply(maxLimit)
        LSP8IdentifiableDigitalAsset(name_, symbol_, newOwner_, _LSP4_TOKEN_TYPE_NFT, _LSP8_TOKENID_FORMAT_UNIQUE_ID)
    {
        placeholder = placeholderCollection;
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
        if (msg.sender != placeholder) {
            revert OnlyPlaceholderCanMint();
        }

        if (assetId == bytes12(0)) {
            revert AssetIdCannotBeZero();
        }

        TokenId memory tokenIdObj = TokenId(
            TokenUtils.collectionId(address(this)),
            variantId,
            assetId
        );
        bytes32 variantDataKey = TokenUtils.getDataKey(tokenIdObj);

        if (!_variants.contains(variantDataKey)) {
            revert VariantNotRegistered();
        }

        bytes32 tokenId = TokenUtils.getTokenId(tokenIdObj);

        if (_exists(tokenId)) {
            revert AssetAlreadyRegistered();
        }

        bytes memory tokenMetaData = _getData(variantDataKey);
        setDataForTokenId(tokenId, _LSP4_METADATA_KEY, tokenMetaData);

        _mint(to, tokenId, allowNonLSP1Recipient, data);

        emit AssetMinted(variantId, assetId, tokenId);
    }

    function registerVariant(
        bytes12 variantId,
        bytes memory metadataUrl
    ) public onlyOwner {
        bytes32 variantDataKey = TokenUtils.getDataKey(
            address(this),
            variantId
        );

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

    function unregisterVariant(bytes12 variantId) public onlyOwner {
        bytes32 variantDataKey = TokenUtils.getDataKey(
            address(this),
            variantId
        );

        if (!_variants.contains(variantDataKey)) {
            revert VariantNotRegistered();
        }

        _variants.remove(variantDataKey);

        emit VariantUnregistered(variantId);
    }

    function checkVariant(bytes12 variantId) public view returns (bool) {
        bytes32 variantDataKey = TokenUtils.getDataKey(
            address(this),
            variantId
        );

        return _variants.contains(variantDataKey);
    }

    function getAssetTokenId(
        bytes12 variantId,
        bytes12 assetId
    ) public view returns (bytes32) {
        return TokenUtils.getTokenId(address(this), variantId, assetId);
    }

    function supportsInterface(
        bytes4 _interfaceId
    ) public view override returns (bool) {
        return
            _interfaceId == type(IAssetVariants).interfaceId ||
            _interfaceId == _INTERFACEID_CAPPED_LSP8 ||
            super.supportsInterface(_interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        bytes32 tokenId,
        bytes memory data
    ) internal virtual override(LSP8Enumerable, LSP8IdentifiableDigitalAssetCore) {
        LSP8Enumerable._beforeTokenTransfer(from, to, tokenId, data);
    }

    function _mint(
        address to,
        bytes32 tokenId,
        bool force,
        bytes memory data
    ) internal virtual override(LSP8CappedSupply, LSP8IdentifiableDigitalAssetCore) {
        LSP8CappedSupply._mint(to, tokenId, force, data);
    }
}
