// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import {LSP8IdentifiableDigitalAsset} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8IdentifiableDigitalAsset.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {LSP8Enumerable} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/extensions/LSP8Enumerable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./constants.sol";

contract Pass is LSP8Enumerable {
    event Received(address, uint);

    using EnumerableSet for EnumerableSet.AddressSet;



    // receive() external payable {
    //     emit Received(msg.sender, msg.value);
    // }
    EnumerableSet.AddressSet minters; 


    address public familyReceiver;

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
        address receiver
    )
        LSP8IdentifiableDigitalAsset(
            name_,
            symbol_,
            newOwner_,
            _LSP4_TOKEN_TYPE_NFT,
            _LSP8_TOKENID_FORMAT_NUMBER
        )
    {
        familyReceiver = receiver;
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

    function getTotalMint() public view returns (uint256 number){
        number=minters.length();
    }
    function hasMinted(address user) public view returns (bool minted){
        minted=minters.contains(user);
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

    function mintFiat(address to)external onlyOwner(){
        require(!minters.contains(to), "User minted pass Already");
            uint256 nextId = _existingTokens + 1;
            _mint(to, bytes32(nextId), true, "0x");
            minters.add(to);
    }

    function getMintHash(address minter, uint256 maxBlock, uint256 price) public pure returns (bytes memory message) {
        message = bytes.concat(abi.encodePacked(minter), abi.encodePacked(maxBlock), abi.encodePacked(price));
    }


    function mintLYX(bytes memory signature, uint256 maxBlock, uint256 price)external payable{
        require(!minters.contains(msg.sender), "User minted pass Already");
        require(block.number<=maxBlock, "Block limit exceeded");
        require(msg.value==price, "Invalid price");
        uint256 nextId = _existingTokens + 1;
        (bool success, )=payable(familyReceiver).call{value:price}("");
        require(success, 'TransferHelper::safeTransferLYX: LYX transfer failed');
        bytes memory message = bytes.concat(abi.encodePacked(msg.sender),abi.encodePacked(maxBlock), abi.encodePacked(price));
        
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(keccak256(message));

        if (_isValidSignature(messageHash, signature) != _ERC1271_MAGICVALUE) {
            revert InvalidFamilySignature();
        }
            
        _mint(msg.sender, bytes32(nextId), true, "0x");
        minters.add(msg.sender);
    }

    function _isValidSignature(
        bytes32 dataHash,
        bytes memory signature
    ) internal view returns (bytes4 magicValue) {
        address target= owner();
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
