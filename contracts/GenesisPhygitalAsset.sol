// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "./constants.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {LSP8IdentifiableDigitalAsset} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8IdentifiableDigitalAsset.sol";
import {LSP8Enumerable} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/extensions/LSP8Enumerable.sol";
import {LSP8CappedSupply} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/extensions/LSP8CappedSupply.sol";

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
        bytes12 variantId,
        uint256 amount,
        bool allowNonLSP1Recipient,
        bytes memory data
    ) external;
}

contract GenesisPhygitalAsset is LSP8Enumerable, IAssetVariants {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.Bytes32Set internal _variants;
    EnumerableSet.AddressSet internal whitelistedMarketplaces;

    event Received(address, uint);
    event VariantRegistered(bytes12 variantId);
    event VariantUnregistered(bytes12 variantId);
    event AssetMinted(
        bytes12 indexed variantId,
        bytes32 indexed tokenId
    );

    error OnlyMinterCanMint();

    error VariantAlreadyRegistered();
    error VariantNotRegistered();

    error AssetAlreadyRegistered();

    error AssetIdCannotBeZero();
    error VariantIdCannotBeZero();

    constructor(
        string memory name_,
        string memory symbol_,
        address newOwner_
    ) LSP8IdentifiableDigitalAsset(name_, symbol_, newOwner_, _LSP4_TOKEN_TYPE_NFT, _LSP8_TOKENID_FORMAT_UNIQUE_ID) {}

    // receive() external payable {
    //     emit Received(msg.sender, msg.value);
    // }

    /**
     * Mint a token for an asset of a specific variant
     *
     * @param to Address of the UP to mint token to
     * @param variantId A bytes12 long identifier for a variant
     * @param allowNonLSP1Recipient A bool to check if only minting should only be allowed to UPs
     * @param data arbitary data
     */
    function mint(
        address to,
        bytes12 variantId,
        uint256 amount,
        bool allowNonLSP1Recipient,
        bytes memory data
    ) public onlyOwner {
        for (uint256 i; i < amount; ) {
            bytes32 tokenId = bytes32(uint256(_existingTokens + 1));
            bytes32 variantDataKey = TokenUtils.getDataKey(address(this), variantId);

            if (!_variants.contains(variantDataKey)) {
                revert VariantNotRegistered();
            }

            if (_exists(tokenId)) {
                revert AssetAlreadyRegistered();
            }

            bytes memory metadata = _getData(variantDataKey);
            _mint(to, tokenId, allowNonLSP1Recipient, data);
            _setDataForTokenId(tokenId, _LSP4_METADATA_KEY, metadata);

            emit AssetMinted(variantId, tokenId);

            // Increment the iterator in unchecked block to save gas
            unchecked {
                ++i;
            }
        }
    }

    function whitelistMarketplace(address _marketplace) public onlyOwner {
        require(
            !whitelistedMarketplaces.contains(_marketplace),
            "Already Whitelisted"
        );
        whitelistedMarketplaces.add(_marketplace);
    }

    function removeMarketplace(address _marketplace) public onlyOwner {
        require(
            whitelistedMarketplaces.contains(_marketplace),
            "Marketplace not whitelisted"
        );
        whitelistedMarketplaces.remove(_marketplace);
    }

    function authorizeOperator(
        address operator,
        bytes32 tokenId,
        bytes memory operatorNotificationData
    ) public override {
        require(
            whitelistedMarketplaces.contains(operator),
            "Operator not whitelisted"
        );
        super.authorizeOperator(operator, tokenId, operatorNotificationData);
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
}
