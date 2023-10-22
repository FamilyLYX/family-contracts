// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// import "hardhat/console.sol";
// import "./constants.sol";

import {LSP14Ownable2Step} from "@lukso/lsp-smart-contracts/contracts/LSP14Ownable2Step/LSP14Ownable2Step.sol";
import {LSP9VaultInit} from "@lukso/lsp-smart-contracts/contracts/LSP9Vault/LSP9VaultInit.sol";

contract FamilyVaultFactory is LSP14Ownable2Step {
  event VaultCreated(address indexed vault);

  constructor(
    address initialOwner
  ) {
    _setOwner(initialOwner);
  }

  function createVault(address newOwner) public onlyOwner {
    LSP9VaultInit vault = new LSP9VaultInit();

    vault.initialize(newOwner);

    emit VaultCreated(address(vault));
  }
}
