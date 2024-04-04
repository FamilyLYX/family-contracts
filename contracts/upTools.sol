// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./constants.sol";
// import "hardhat/console.sol";

import {LSP6KeyManagerCore} from "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6KeyManagerCore.sol";
import {LSP0ERC725Account} from "@lukso/lsp-smart-contracts/contracts/LSP0ERC725Account/LSP0ERC725Account.sol";
import {ILSP14Ownable2Step} from "@lukso/lsp-smart-contracts/contracts/LSP14Ownable2Step/ILSP14Ownable2Step.sol";
import {LSP2Utils} from "@lukso/lsp-smart-contracts/contracts/LSP2ERC725YJSONSchema/LSP2Utils.sol";
import {LSP6Utils} from "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6Utils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {ERC725Y} from "@erc725/smart-contracts/contracts/ERC725Y.sol";

contract CustomKeyManager is LSP6KeyManagerCore {
    using LSP6Utils for *;
    using ECDSA for *;

    constructor(address target) {
        _target = target;
        // _setupLSP6ReentrancyGuard();
    }

    function getTarget() public view returns (address) {
        return _target;
    }

    function updateTarget(address newTarget_) public {
        _target = newTarget_;
    }

    function acceptOwnership(address target) public {
        ILSP14Ownable2Step(target).acceptOwnership();
    }

    function isValidSignature(
        bytes32 dataHash,
        bytes memory signature
    ) public view override returns (bytes4 magicValue) {
        // if isValidSignature fail, the error is catched in returnedError
        (address recoveredAddress, ECDSA.RecoverError returnedError) = ECDSA
            .tryRecover(dataHash, signature);

        // if recovering throws an error, return the fail value
        if (returnedError != ECDSA.RecoverError.NoError)
            return _ERC1271_FAILVALUE;

        // if the address recovered has SIGN permission return the ERC1271 magic value, otherwise the fail value
        return (
            ERC725Y(_target).getPermissionsFor(recoveredAddress).hasPermission(
                _PERMISSION_SIGN
            )
                ? _ERC1271_MAGICVALUE
                : _ERC1271_FAILVALUE
        );
    }
}

contract CustomUniversalProfule is LSP0ERC725Account {
    constructor(address initialOwner) payable LSP0ERC725Account(initialOwner) {
        // set data key SupportedStandards:LSP3UniversalProfile
        _setData(
            _LSP3_SUPPORTED_STANDARDS_KEY,
            _LSP3_SUPPORTED_STANDARDS_VALUE
        );
    }

    function _getExtension(
        bytes4 functionSelector
    ) internal view override returns (address) {
        // Generate the data key relevant for the functionSelector being called
        bytes32 mappedExtensionDataKey = LSP2Utils.generateMappingKey(
            _LSP17_EXTENSION_PREFIX,
            functionSelector
        );

        // Check if there is an extension stored under the generated data key
        address extension = address(bytes20(_getData(mappedExtensionDataKey)));

        return extension;
    }
}
