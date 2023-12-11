// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import {LSP8IdentifiableDigitalAsset} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8IdentifiableDigitalAsset.sol";
import {LSP8Enumerable} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/extensions/LSP8Enumerable.sol";

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
    ) LSP8IdentifiableDigitalAsset(name_, symbol_, newOwner_, 3, 3) {
        minter = _minter;
    }

    function mint(address receiver) external {
        require(msg.sender == minter, "Sender not minter");
        uint256 nextId = _existingTokens + 1;
        _mint(receiver, bytes32(nextId), true, "0x");
    }
}
