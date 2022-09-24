//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract FishdomNFT is ERC721Upgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using StringsUpgradeable for uint256;

    CountersUpgradeable.Counter private _tokenCounter;
    address private _owner;
    string public _baseUri;

    function initialize(
        string memory name_,
        string memory symbol_,
        string memory baseUri_
    ) public initializer {
        __ERC721_init(name_, symbol_);
        _owner = msg.sender;
        _tokenCounter.increment();
        _baseUri = baseUri_;
    }

    // setBaseUri for NFT
    function setBaseUri(string calldata baseUri_) external onlyOwner {
        _baseUri = baseUri_;
    }

    /**
     * @dev Only mint for the owner
     * @param number - the number crown
     */
    function mint(uint256 number) external onlyOwner {
        for (uint256 i = 0; i < number; i++) {
            _mint(msg.sender, _tokenCounter.current());
            _tokenCounter.increment();
        }
    }

    function burn(uint256 tokenId) public {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "CROWNNFT: Not owner or approved by owner"
        );
        _burn(tokenId);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        _owner = newOwner;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "FishdomNFT: Only owner");
        _;
    }
}
