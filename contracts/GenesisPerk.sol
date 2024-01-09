// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import {LSP8IdentifiableDigitalAsset} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8IdentifiableDigitalAsset.sol";
import {LSP8Enumerable} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/extensions/LSP8Enumerable.sol";
import "./constants.sol";

contract GenesisPerk is LSP8Enumerable {
    event Received(address, uint);
    address minter;

    // receive() external payable {
    //     emit Received(msg.sender, msg.value);
    // }

    constructor(
        string memory name_,
        string memory symbol_,
        address newOwner_,
        address _minter
    ) LSP8IdentifiableDigitalAsset(name_, symbol_, newOwner_, 1, 0) {
        minter = _minter;
    }

    function mint(address receiver) external {
        require(
            msg.sender == minter || msg.sender == owner(),
            "Sender not minter"
        );
        uint256 nextId = _existingTokens + 1;
        // // Set the token id type to be bytes32
        uint tokenIdType = 0;
        _setData(_DATAKEY_TOKENID_TYPE, abi.encodePacked(tokenIdType));
        _mint(receiver, bytes32(nextId), false, "0x");
    }
}
