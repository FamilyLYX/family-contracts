// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import {LSP8IdentifiableDigitalAsset} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8IdentifiableDigitalAsset.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {LSP8Enumerable} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/extensions/LSP8Enumerable.sol";
import {LSP8CappedSupply} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/extensions/LSP8CappedSupply.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./constants.sol";

contract GiveawayPass is LSP8CappedSupply {
    event Received(address, uint);

    using EnumerableSet for EnumerableSet.AddressSet;

    // receive() external payable {
    //     emit Received(msg.sender, msg.value);
    // }
    EnumerableSet.AddressSet minters;

    address public familyReceiver;
    address public orderExtension;

    bytes public defaultTokenUri;
    event DefaultTokenDataChanged(bytes newTokenUri);

    error InvalidFamilySignature();

    bytes32 constant _LSP4_DATAKEY =
        0x9afb95cacc9f95858ec44aa8c3b685511002e30ae54415823f406128b85b238e;
    bytes32 private constant _LSP8_TOKEN_METADATA_BASE_URI_KEY =
        0x1a7628600c3bac7101f53697f48df381ddc36b9015e7d7c9c5633d1252aa2843;

    constructor(
        string memory name_,
        string memory symbol_,
        address newOwner_,
        address receiver,
        address extension
    )
        LSP8IdentifiableDigitalAsset(
            name_,
            symbol_,
            newOwner_,
            _LSP4_TOKEN_TYPE_NFT,
            _LSP8_TOKENID_FORMAT_NUMBER
        )
        LSP8CappedSupply(257)
    {
        familyReceiver = receiver;
        orderExtension = extension;
    }

    function setDefaultTokenUri(bytes calldata newTokenUri) external onlyOwner {
        defaultTokenUri = newTokenUri;
        emit DefaultTokenDataChanged(newTokenUri);
    }

    function updateOrderExtension(address extension) public onlyOwner {
        orderExtension = extension;
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

    function getTotalMint() public view returns (uint256 number) {
        number = minters.length();
    }
    function hasMinted(address user) public view returns (bool minted) {
        minted = minters.contains(user);
    }

    // function mint() external payable {
    //     require(!minters.contains(msg.sender), "User minted pass Already");
    //         uint256 nextId = _existingTokens + 1;
    //         if(fee>0){
    //             (bool success, )=payable(familyReceiver).call{value:fee}("");
    //             require(success, 'TransferHelper::safeTransferETH: ETH transfer failed');
    //         }
    //         _mint(msg.sender, bytes32(nextId), true, "0x");
    //         minters.add(msg.sender);
    // }

    function mint(address to) external onlyOwner {
        require(!minters.contains(to), "User minted pass Already");
        uint256 nextId = _existingTokens + 1;
        _mint(to, bytes32(nextId), true, "0x");
        minters.add(to);
    }

    function getMintHash(
        address minter,
        uint256 maxBlock,
        uint256 price
    ) public pure returns (bytes memory message) {
        message = bytes.concat(
            abi.encodePacked(minter),
            abi.encodePacked(maxBlock),
            abi.encodePacked(price)
        );
    }

    function burn(bytes32 tokenId, bytes memory data) external {
        require(msg.sender == orderExtension, "Access Denied");
        _burn(tokenId, data);
    }
}
