// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import {LSP8IdentifiableDigitalAsset} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8IdentifiableDigitalAsset.sol";
import {LSP8Enumerable} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/extensions/LSP8Enumerable.sol";
import "./constants.sol";

contract GenesisPerk is LSP8Enumerable {
    event Received(address, uint);

    // receive() external payable {
    //     emit Received(msg.sender, msg.value);
    // }

    address minter;

    bytes public defaultTokenUri;
    event DefaultTokenDataChanged(bytes newTokenUri);

    bytes32 constant _LSP4_DATAKEY =
        0x9afb95cacc9f95858ec44aa8c3b685511002e30ae54415823f406128b85b238e;
    bytes32 private constant _LSP8_TOKEN_METADATA_BASE_URI_KEY =
        0x1a7628600c3bac7101f53697f48df381ddc36b9015e7d7c9c5633d1252aa2843;

    constructor(
        string memory name_,
        string memory symbol_,
        address newOwner_,
        address minter_
    )
        LSP8IdentifiableDigitalAsset(
            name_,
            symbol_,
            newOwner_,
            _LSP4_TOKEN_TYPE_NFT,
            _LSP8_TOKENID_FORMAT_NUMBER
        )
    {
        minter = minter_;
    }

    function setDefaultTokenUri(bytes calldata newTokenUri) external onlyOwner {
        defaultTokenUri = newTokenUri;
        emit DefaultTokenDataChanged(newTokenUri);
    }

    function _getDataForTokenId(
        bytes32 tokenId,
        bytes32 dataKey
    ) internal view override returns (bytes memory) {
        bytes memory result = super._getDataForTokenId(tokenId, dataKey);
        if (dataKey == _LSP4_DATAKEY && result.length == 0) {
            bytes memory baseUri = super._getData(
                _LSP8_TOKEN_METADATA_BASE_URI_KEY
            );
            if (baseUri.length == 0) {
                return defaultTokenUri;
            }
        }
        return result;
    }

    function mint(address receiver, uint256 amount) external {
        require(
            msg.sender == owner() || msg.sender == minter,
            "Sender not minter"
        );
        for (uint256 i; i < amount; ) {
            uint256 nextId = _existingTokens + 1;
            _mint(receiver, bytes32(nextId), false, "0x");

            // Increment the iterator in unchecked block to save gas
            unchecked {
                ++i;
            }
        }
    }
}
