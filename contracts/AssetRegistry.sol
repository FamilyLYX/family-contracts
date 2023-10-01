// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "./constants.sol";

import {LSP14Ownable2Step} from "@lukso/lsp-smart-contracts/contracts/LSP14Ownable2Step/LSP14Ownable2Step.sol";
import {LSP2Utils} from "@lukso/lsp-smart-contracts/contracts/LSP2ERC725YJSONSchema/LSP2Utils.sol";

import {ERC725Y} from "@erc725/smart-contracts/contracts/ERC725Y.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {BytesLib} from "solidity-bytes-utils/contracts/BytesLib.sol";

interface IAssetRegistry {
  function register(bytes32 identifier, address collection, bytes32 tokenId) external;
  function checkToken(address collection, bytes32 tokenId) external view returns (bytes32);
  function checkIdentifier(bytes32 identifier) external view returns (address, bytes32);
}

struct Asset {
  address collection;
  bytes32 id;
}

contract AssetRegistry is LSP14Ownable2Step, IAssetRegistry {
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.Bytes32Set;
  using BytesLib for bytes;

  EnumerableSet.AddressSet internal _registars;
  EnumerableSet.Bytes32Set internal _identifiersPool;
  mapping(bytes32 => bytes32) internal _identifierTokenMap;
  mapping(bytes32 => address) internal _identifierCollectionMap;

  mapping(bytes32 => bytes32) internal _tokenIdentifierMap;

  error RegistarNotFound();
  error IdentifiersListEmpty();
  error IdentifierAlreadyExists(bytes32 identifier);
  error IdentifierAlreadyRegistered(bytes32 identifier, bytes32 tokenId);
  error IdentifierNotRegistered();
  error IdentifierCollectionMismatch();

  event AssetRegistered(address registar, address collection, bytes32 tokenId, bytes32 identifier);

  constructor(
    address initialOwner
  ) {
    _setOwner(initialOwner);
  }

  function addToPool(bytes32[] memory identifiers, address collection) public onlyOwner {
    if (identifiers.length == 0) {
      revert IdentifiersListEmpty();
    }

    for (uint256 i = 0; i < identifiers.length; ) {
      if (_identifiersPool.contains(identifiers[i])) {
        revert IdentifierAlreadyExists(identifiers[i]);
      }

      _identifiersPool.add(identifiers[i]);
      _identifierCollectionMap[identifiers[i]] = collection;

      // Increment the iterator in unchecked block to save gas
      unchecked {
          ++i;
      }
    }
  }

  function register (bytes32 identifier, address collection, bytes32 tokenId) public {
    if (!_registars.contains(msg.sender)) {
      revert RegistarNotFound();
    }

    bytes32 existingTokenId = _identifierTokenMap[identifier];
    address _collection = _identifierCollectionMap[identifier];

    if (!_identifiersPool.contains(identifier)) {
      revert IdentifierNotRegistered();
    }

    if (existingTokenId != bytes32(0)) {
      revert IdentifierAlreadyRegistered(identifier, existingTokenId);
    }

    if (_collection != collection) {
      revert IdentifierCollectionMismatch();
    }

    bytes32 tokenHash = keccak256(bytes.concat(bytes20(collection), tokenId));
    _identifierTokenMap[identifier] = tokenId;
    _tokenIdentifierMap[tokenHash] = identifier;

    emit AssetRegistered(msg.sender, collection, tokenId, identifier);
  }

  function checkToken(address collection, bytes32 tokenId) public view returns (bytes32 identifier) {
    bytes32 tokenHash = keccak256(bytes.concat(bytes20(collection), tokenId));

    identifier = _tokenIdentifierMap[tokenHash];
  }

  function checkIdentifier(bytes32 identifier) public view returns (address collection, bytes32 tokenId) {
    collection = _identifierCollectionMap[identifier];
    tokenId = _identifierTokenMap[identifier];
  }

  function addAddress(address _address) public onlyOwner {
      // require(
      //     ERC165(_address).supportsInterface(_INTERFACEID_ERC725Y),
      //     "Only ERC725Y addresses can be added"
      // );
      _registars.add(_address);
  }

  function removeAddress(address _address) public onlyOwner {
      // require(
      //     ERC165(msg.sender).supportsInterface(_INTERFACEID_ERC725Y),
      //     "Only ERC725Y can call this function"
      // );
      _registars.remove(_address);
  }

  function totalSupply() public view returns (uint256) {
    return _identifiersPool.length();
  }

  function identifierAt(uint256 index) public view returns (bytes32) {
    return _identifiersPool.at(index);
  }

  function totalRegistars() public view returns (uint256) {
    return _registars.length();
  }

  function registarAt(uint256 index) public view returns (address) {
    return _registars.at(index);
  }
}
