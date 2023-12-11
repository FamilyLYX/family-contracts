// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "./constants.sol";

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IERC725Y} from "@erc725/smart-contracts/contracts/interfaces/IERC725Y.sol";

import {LSP8IdentifiableDigitalAsset} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8IdentifiableDigitalAsset.sol";
import {LSP8NotTokenOperator} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8Errors.sol";
import {LSP2Utils} from "@lukso/lsp-smart-contracts/contracts/LSP2ERC725YJSONSchema/LSP2Utils.sol";

import {BytesLib} from "solidity-bytes-utils/contracts/BytesLib.sol";

import {IAssetVariants} from "./IdentifiablePhygitalAsset.sol";
import {IAssetRegistry} from "./AssetRegistry.sol";
import {TokenUtils, TokenId} from "./TokenUtils.sol";

interface IAssetPlaceholder {
    function register(
        bytes32 uid,
        address collection,
        bytes32 tokenId
    ) external;
}

interface CappedSupply {
    function tokenSupplyCap() external view returns (uint256);
}

contract AssetPlaceholder is LSP8IdentifiableDigitalAsset {
    using BytesLib for bytes;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using TokenUtils for TokenId;

    struct CollectionMeta {
        uint48 startAt;
        uint48 endAt;
        uint96 count;
    }

    address public assetRegistry;

    mapping(address => CollectionMeta) public collectionMeta;
    mapping(bytes6 => address) public collections;

    EnumerableSet.Bytes32Set internal _frozen;

    event Received(address, uint);

    error CollectionNotRegistered();
    error CollectionAlreadyRegistered();
    error CollectionAddressCannotBeZero();
    error MintLimitReachedForCollection();
    error VariantNotRegistered();
    error MintingPeriodNotStarted();
    error MintingPeriodEnded();
    error TokenIsFrozen();
    error TokenNotReadyToBeRegistered();
    error InvalidFamilySignature();

    constructor(
        string memory name_,
        string memory symbol_,
        address newOwner_,
        address assetRegistry_
    ) LSP8IdentifiableDigitalAsset(name_, symbol_, newOwner_, 3, 3) {
        assetRegistry = assetRegistry_;
    }

    // receive() external payable {
    //     emit Received(msg.sender, msg.value);
    // }

    function registerCollection(
        address collection,
        uint48 startAt,
        uint48 duration
    ) public onlyOwner {
        bytes6 collectionId = TokenUtils.collectionId(collection);

        if (collection == address(0)) {
            revert CollectionAddressCannotBeZero();
        }

        if (collections[collectionId] != address(0)) {
            revert CollectionAlreadyRegistered();
        }

        CollectionMeta memory meta = CollectionMeta(
            startAt,
            startAt + duration,
            0
        );

        collectionMeta[collection] = meta;
        collections[collectionId] = collection;
    }

    function updateMintDuration(
        address collection,
        uint48 duration
    ) public onlyOwner {
        bytes6 collectionId = TokenUtils.collectionId(collection);

        if (collections[collectionId] == address(0)) {
            revert CollectionNotRegistered();
        }

        collectionMeta[collection].endAt =
            collectionMeta[collection].startAt +
            duration;
    }

    function register(
        string memory uid,
        bytes memory signature,
        bytes32 _tokenId
    ) public {
        address operator = msg.sender;
        bytes32 messageHash = keccak256(
            bytes.concat(_MSG_HASH_PREFIX, bytes(uid))
        );

        if (_isValidSignature(messageHash, signature) != _ERC1271_MAGICVALUE) {
            revert InvalidFamilySignature();
        }

        if (!_isOperatorOrOwner(operator, _tokenId)) {
            revert LSP8NotTokenOperator(_tokenId, operator);
        }

        if (!_frozen.contains(_tokenId)) {
            revert TokenNotReadyToBeRegistered();
        }

        TokenId memory tokenId = TokenUtils.parseTokenId(_tokenId);
        address collection = collections[tokenId.collectionId];

        bytes32 identifier = keccak256(bytes(uid));

        IAssetRegistry(assetRegistry).register(
            identifier,
            collection,
            _tokenId
        );

        // TODO: Think about where to mint the token to, operator or owner.
        IAssetVariants(collection).mint(
            msg.sender,
            tokenId.assetId,
            tokenId.variantId,
            true,
            "0x"
        );

        // TODO: Add unit test to ensure that if a token is burned, it cannot be minted again.
        _burn(_tokenId, "0x");
    }

    function transfer(
        address from,
        address to,
        bytes32 tokenId,
        bool allowNonLSP1Recipient,
        bytes memory data
    ) public override {
        if (_frozen.contains(tokenId)) {
            revert TokenIsFrozen();
        }

        _transfer(from, to, tokenId, allowNonLSP1Recipient, data);
    }

    function freeze(bytes32 tokenId) public onlyOwner {
        _frozen.add(tokenId);
    }

    function mint(
        address to,
        address collection,
        bytes12 variantId,
        bool allowNonLSP1Recipient,
        bytes memory data,
        bool frozen
    ) public onlyOwner {
        bytes6 collectionId = TokenUtils.collectionId(collection);
        CollectionMeta memory meta = collectionMeta[collection];

        if (block.timestamp < meta.startAt) {
            revert MintingPeriodNotStarted();
        }

        if (block.timestamp > meta.endAt) {
            revert MintingPeriodEnded();
        }

        _prepareMint(collectionId, variantId);
        bytes12 assetId = bytes12(
            abi.encodePacked(collectionMeta[collection].count)
        );
        bytes32 tokenId = TokenUtils.getTokenId(collection, variantId, assetId);

        _mint(to, tokenId, allowNonLSP1Recipient, data);

        if (frozen) {
            _frozen.add(tokenId);
        }
    }

    function _prepareMint(bytes6 collectionId, bytes12 variantId) internal {
        address collection = collections[collectionId];
        uint96 mintCount = collectionMeta[collection].count;

        if (collection == address(0)) {
            revert CollectionNotRegistered();
        }

        if (IERC165(collection).supportsInterface(_INTERFACEID_CAPPED_LSP8)) {
            uint256 mintLimit = CappedSupply(collection).tokenSupplyCap();

            if (uint256(mintCount) == mintLimit) {
                revert MintLimitReachedForCollection();
            }
        }

        if (
            IERC165(collection).supportsInterface(
                type(IAssetVariants).interfaceId
            )
        ) {
            if (!IAssetVariants(collection).checkVariant(variantId)) {
                revert VariantNotRegistered();
            }
        }

        collectionMeta[collection].count = mintCount + 1;
    }

    function _getData(
        bytes32 dataKey
    ) internal view override returns (bytes memory dataValue) {
        bytes10 mappingKeyPrefix = bytes10(dataKey);

        if (mappingKeyPrefix == _LSP8_TOKEN_METADATA_KEY_PREFIX) {
            TokenId memory tokenId = TokenUtils.parseDataKey(dataKey);
            address collection = collections[tokenId.collectionId];

            if (collection == address(0)) {
                return _store[dataKey];
            }

            bytes32 referredDataKey = TokenUtils.getDataKey(tokenId);

            return IERC725Y(collection).getData(referredDataKey);
        }

        return _store[dataKey];
    }

    function supportsInterface(
        bytes4 _interfaceId
    ) public view override returns (bool) {
        return
            _interfaceId == type(IAssetPlaceholder).interfaceId ||
            super.supportsInterface(_interfaceId);
    }

    function _isValidSignature(
        bytes32 dataHash,
        bytes memory signature
    ) internal view returns (bytes4 magicValue) {
        address _owner = owner();

        // If owner is a contract
        if (_owner.code.length > 0) {
            (bool success, bytes memory result) = _owner.staticcall(
                abi.encodeWithSelector(
                    IERC1271.isValidSignature.selector,
                    dataHash,
                    signature
                )
            );

            bool isValid = (success &&
                result.length == 32 &&
                abi.decode(result, (bytes32)) == bytes32(_ERC1271_MAGICVALUE));

            return isValid ? _ERC1271_MAGICVALUE : _ERC1271_FAILVALUE;
        }
        // If owner is an EOA
        else {
            // if isValidSignature fail, the error is catched in returnedError
            (address recoveredAddress, ECDSA.RecoverError returnedError) = ECDSA
                .tryRecover(dataHash, signature);

            // if recovering throws an error, return the fail value
            if (returnedError != ECDSA.RecoverError.NoError)
                return _ERC1271_FAILVALUE;

            // if recovering is successful and the recovered address matches the owner's address,
            // return the ERC1271 magic value. Otherwise, return the ERC1271 fail value
            // matches the address of the owner, otherwise return fail value
            return
                recoveredAddress == _owner
                    ? _ERC1271_MAGICVALUE
                    : _ERC1271_FAILVALUE;
        }
    }
}
