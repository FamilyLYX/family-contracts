// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "./constants.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {LSP8IdentifiableDigitalAsset} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8IdentifiableDigitalAsset.sol";
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
        bool allowNonLSP1Recipient,
        bytes memory data
    ) external;
}

contract GenesisPhygitalAsset is LSP8CappedSupply, IAssetVariants {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.Bytes32Set internal _variants;
    EnumerableSet.AddressSet internal whitelistedMarketplaces;

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
        uint256 maxLimit
    )
        LSP8CappedSupply(maxLimit)
        LSP8IdentifiableDigitalAsset(name_, symbol_, newOwner_, 3, 3)
    {
        // Set the token id type to be bytes32
        uint tokenIdType = 3;
        _setData(_DATAKEY_TOKENID_TYPE, abi.encodePacked(tokenIdType));
    }

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
        bool allowNonLSP1Recipient,
        bytes memory data
    ) public onlyOwner {
        // if (msg.sender != placeholder) {
        //     revert OnlyPlaceholderCanMint();
        // }

        bytes12 assetId = bytes12(abi.encodePacked(_existingTokens + 1));
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
        bytes memory metadata = getData(variantId);
        bytes32 metadataKey = bytes32(
            bytes.concat(_LSP8_TOKEN_METADATA_KEY_PREFIX, tokenId)
        );

        _mint(to, tokenId, allowNonLSP1Recipient, data);
        setData(metadataKey, metadata);

        emit AssetMinted(variantId, assetId, tokenId);
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
