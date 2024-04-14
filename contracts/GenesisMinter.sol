// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./constants.sol";

interface IGenesisPerk {
    function mint(address receiver, uint256 amount) external;
}

interface IGenesisCollection {
    function mint(
        address to,
        bytes12 variantId,
        bool allowNonLSP1Recipient,
        bytes memory data
    ) external;
}

contract GenesisMinter {
    address internal genesisCollection;
    address internal genesisPerk;
    address internal owner;

    mapping(string => bool) internal mintedUsers;

    error InvalidFamilySignature();

    constructor(address _owner) {
        owner = _owner;
    }

    function setCollections(address genesis, address perk) external {
        genesisCollection = genesis;
        genesisPerk = perk;
    }

    function mintGenesis(
        address to,
        bytes12 variantId,
        bool allowNonLSP1Recipient,
        bytes memory data,
        uint256 amount,
        string memory uid
    ) external {
        require(mintedUsers[uid] == false, "User already minted");
        require(msg.sender == owner, "Only FamilyUP can mint");

        if (amount > 1) {
            for (uint256 i; i < amount; ) {
                IGenesisCollection(genesisCollection).mint(
                    to,
                    variantId,
                    allowNonLSP1Recipient,
                    data
                );

                // Increment the iterator in unchecked block to save gas
                unchecked {
                    ++i;
                }
            }
        } else {
            IGenesisCollection(genesisCollection).mint(
                to,
                variantId,
                allowNonLSP1Recipient,
                data
            );
        }

        IGenesisPerk(genesisPerk).mint(to, amount);
        mintedUsers[uid] = true;
    }
}
