/**
 * This contract uses for management multiple allowed tokens
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Interface/IResolver.sol";

contract Resolver is IResolver {
    address private admin;
    mapping(bytes32 => address) private addresses;

    constructor(address _admin) {
        admin = _admin;
    }

    function getPaymentToken(string memory _name)
        external
        view
        override
        returns (address)
    {
        return addresses[keccak256(abi.encodePacked(_name))];
    }

    function setPaymentToken(string memory _name, address _v)
        external
        override
    {
        require(
            addresses[keccak256(abi.encodePacked(_name))] == address(0),
            "ReNFT::cannot reset the address"
        );
        require(msg.sender == admin, "ReNFT::only admin");
        addresses[keccak256(abi.encodePacked(_name))] = _v;
    }
}
