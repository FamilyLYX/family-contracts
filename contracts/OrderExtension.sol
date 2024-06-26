// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./constants.sol";
// import "hardhat/console.sol";

import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC725X} from "@erc725/smart-contracts/contracts/ERC725XCore.sol";

import {LSP17Extension} from "@lukso/lsp-smart-contracts/contracts/LSP17ContractExtension/LSP17Extension.sol";
import {ILSP0ERC725Account} from "@lukso/lsp-smart-contracts/contracts/LSP0ERC725Account/ILSP0ERC725Account.sol";
import {ILSP8IdentifiableDigitalAsset} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/ILSP8IdentifiableDigitalAsset.sol";
import {LSP2Utils} from "@lukso/lsp2-contracts/contracts/LSP2Utils.sol";
import {LSP8Burnable} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/extensions/LSP8Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

bytes2 constant _BURN_AFTER_USE = 0xffff;

contract OrderExtension is LSP17Extension, Ownable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    address target;

    error BlockAlreadyConfirmed();
    error InvalidSignature();
    error IncorrectValue();
    error InvalidNonce();
    error CallerNotTarget();
    error CallerNotPerkOwner();
    error PerkAlreadyClaimed();

    mapping(bytes32 => bool) _nonces;

    mapping(address => EnumerableSet.Bytes32Set) perkClaims;

    event TargetChanged(address newTarget);
    event OrderCreated(bytes orderId);

    constructor(address target_) {
        target = target_;
    }

    function getOrderHash(
        address collection,
        uint256 value,
        uint256 maxBlockNumber,
        bytes32 nonce,
        bytes memory data,
        bytes memory orderId
    ) public pure returns (bytes memory message) {
        message = bytes.concat(
            bytes20(collection),
            abi.encodePacked(value),
            abi.encodePacked(maxBlockNumber),
            nonce,
            data,
            orderId
        );
    }

    function getRedeemPerkHash(
        address collection,
        uint256 value,
        uint256 maxBlockNumber,
        address perkAddress,
        bytes32 perkTokenId,
        bytes32 nonce,
        bytes memory data,
        bytes memory orderId
    ) public pure returns (bytes memory message) {
        message = bytes.concat(
            bytes20(collection),
            abi.encodePacked(value),
            abi.encodePacked(maxBlockNumber),
            bytes20(perkAddress),
            perkTokenId,
            orderId,
            nonce,
            data
        );
    }

    function redeemPerk(
        address collection,
        address perkAddress,
        bytes32 perkTokenId,
        uint256 value,
        uint256 maxBlockNumber,
        bytes32 nonce,
        bytes memory data,
        bytes memory signature,
        bytes memory orderId
    ) public {
        bytes memory message = bytes.concat(
            bytes20(collection),
            abi.encodePacked(value),
            abi.encodePacked(maxBlockNumber),
            bytes20(perkAddress),
            perkTokenId,
            orderId,
            nonce,
            data
        );
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(keccak256(message));

        if (msg.sender != target) {
            revert CallerNotTarget();
        }

        if (block.number > maxBlockNumber) {
            revert BlockAlreadyConfirmed();
        }

        if (_isValidSignature(messageHash, signature) != _ERC1271_MAGICVALUE) {
            revert InvalidSignature();
        }

        if (_extendableMsgValue() != value) {
            revert IncorrectValue();
        }

        if (_nonces[nonce] != false) {
            revert InvalidNonce();
        }

        address perkOwner = ILSP8IdentifiableDigitalAsset(perkAddress)
            .tokenOwnerOf(perkTokenId);

        if (perkOwner != _extendableMsgSender()){
            revert CallerNotPerkOwner();
        }

        if (perkClaims[collection].contains(perkTokenId)) {
            revert PerkAlreadyClaimed();
        }

        perkClaims[collection].add(perkTokenId);

        IERC725X(target).execute(0, collection, 0, data);

        _nonces[nonce] = true;
        emit OrderCreated(orderId);

        bytes32 dataKey = LSP2Utils.generateSingletonKey('BurnAfterUse');
        bytes memory burnAfterUse = ILSP8IdentifiableDigitalAsset(perkAddress).getData(dataKey);

        if (bytes2(burnAfterUse) == _BURN_AFTER_USE) {
            LSP8Burnable(payable(perkAddress)).burn(perkTokenId, orderId);
        }
    }

    function placeOrder(
        address collection,
        uint256 value,
        uint256 maxBlockNumber,
        bytes32 nonce,
        bytes memory data,
        bytes memory signature,
        bytes memory orderId
    ) public {
        bytes memory message = bytes.concat(
            bytes20(collection),
            abi.encodePacked(value),
            abi.encodePacked(maxBlockNumber),
            nonce,
            data,
            orderId
        );
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(keccak256(message));

        if (msg.sender != target) {
            revert CallerNotTarget();
        }

        if (block.number > maxBlockNumber) {
            revert BlockAlreadyConfirmed();
        }

        if (_isValidSignature(messageHash, signature) != _ERC1271_MAGICVALUE) {
            revert InvalidSignature();
        }

        if (_extendableMsgValue() != value) {
            revert IncorrectValue();
        }

        if (_nonces[nonce] != false) {
            revert InvalidNonce();
        }

        IERC725X(target).execute(0, collection, 0, data);

        _nonces[nonce] = true;
        emit OrderCreated(orderId);
    }

    function updateTarget(address _newTarget) public onlyOwner {
        target = _newTarget;

        emit TargetChanged(_newTarget);
    }

    function _isValidSignature(
        bytes32 dataHash,
        bytes memory signature
    ) internal view returns (bytes4 magicValue) {
        // If owner is a contract
        if (target.code.length > 0) {
            (bool success, bytes memory result) = target.staticcall(
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
                recoveredAddress == target
                    ? _ERC1271_MAGICVALUE
                    : _ERC1271_FAILVALUE;
        }
    }
}
