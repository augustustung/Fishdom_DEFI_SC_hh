// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FishdomToken is ERC20, Ownable {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply
    ) ERC20(name_, symbol_) {
        _mint(msg.sender, initialSupply * 10**decimals());
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function mint(uint256 amount, address to) external onlyOwner {
        _mint(to, amount);
    }
}
