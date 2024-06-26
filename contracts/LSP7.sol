// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import {LSP7DigitalAsset} from "@lukso/lsp-smart-contracts/contracts/LSP7DigitalAsset/LSP7DigitalAsset.sol";
import {_LSP4_TOKEN_TYPE_NFT} from "@lukso/lsp-smart-contracts/contracts/LSP4DigitalAssetMetadata/LSP4Constants.sol";

contract LSP7Perk is LSP7DigitalAsset {
    event Received(address, uint);

    constructor(
        string memory name_,
        string memory symbol_,
        address newOwner_
    ) LSP7DigitalAsset(name_, symbol_, newOwner_, _LSP4_TOKEN_TYPE_NFT, true) {}

    function mint(address receiver, uint256 amount) external onlyOwner {
        // // Set the token id type to be bytes32
        _mint(receiver, amount, false, "0x");
    }
}
