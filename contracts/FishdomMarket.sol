// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "./token/IFishdomToken.sol";

contract FishdomMarket is IERC721ReceiverUpgradeable {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    address private _owner;
    IERC721Upgradeable FishdomNFT;
    IFishdomToken FishdomToken;

    constructor(address token_, address nft_) {
        _owner = msg.sender;
        FishdomToken = IFishdomToken(token_);
        FishdomNFT = IERC721Upgradeable(nft_);
    }

    struct MarketItem {
        uint256 itemId;
        uint256 tokenId;
        address seller;
        uint256 price;
    }

    mapping(uint256 => MarketItem) private idToMarketItem;

    event MarketItemCreated(
        uint256 indexed itemId,
        uint256 indexed tokenId,
        address seller,
        uint256 price
    );

    event BuyMarketItem(
        uint256 indexed itemId,
        uint256 indexed tokenId,
        uint256 price,
        address seller,
        address buyer
    );

    event WithdrawItem(
        uint256 indexed itemId,
        uint256 indexed tokenId,
        address owner
    );

    /**
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function setToken(address token) external onlyOwner {
        FishdomToken = IFishdomToken(token);
    }

    function setNFT(address nft) external onlyOwner {
        FishdomNFT = IERC721Upgradeable(nft);
    }

    function createMarketItem(uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be at least 1 wei");
        FishdomNFT.transferFrom(msg.sender, address(this), tokenId);
        _itemIds.increment();
        uint256 itemId = _itemIds.current();
        idToMarketItem[itemId] = MarketItem(itemId, tokenId, msg.sender, price);
        emit MarketItemCreated(itemId, tokenId, msg.sender, price);
    }

    function buyMarketItem(uint256 itemIndex) public {
        MarketItem memory currentItem = idToMarketItem[itemIndex];
        require(currentItem.seller != msg.sender, "Can not buy your item");
        uint256 totalPrice = currentItem.price;
        uint256 allowance = FishdomToken.allowance(msg.sender, address(this));
        require(
            allowance >= totalPrice,
            "FishdomMarket: Please submit the asking price in order to complete the purchase"
        );
        // sell successfully => tax sell 5% of market item's price
        uint256 taxFee = (totalPrice * 5) / 100;
        uint256 tokenId = currentItem.tokenId;
        // send FishdomToken to seller
        bool returnToken = FishdomToken.transferFrom(
            msg.sender,
            currentItem.seller,
            totalPrice - taxFee
        );
        require(
            returnToken,
            "FishdomMarket: Transfer FishdomToken to seller failed"
        );
        // send tax fee to owner
        returnToken = FishdomToken.transferFrom(msg.sender, _owner, taxFee);
        require(returnToken, "FishdomMarket: Transfer tax fee failed");
        delete idToMarketItem[itemIndex];
        FishdomNFT.transferFrom(address(this), msg.sender, tokenId);

        emit BuyMarketItem(
            currentItem.itemId,
            tokenId,
            totalPrice,
            currentItem.seller,
            msg.sender
        );
    }

    function withdrawNFT(uint256 itemId) external {
        MarketItem memory item = idToMarketItem[itemId];
        require(
            idToMarketItem[itemId].seller == msg.sender,
            "FishdomMarket: Not owner"
        );
        delete idToMarketItem[itemId];

        FishdomNFT.transferFrom(address(this), msg.sender, item.tokenId);
        emit WithdrawItem(item.itemId, item.tokenId, item.seller);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        _owner = newOwner;
    }

    modifier onlyOwner() {
        require(msg.sender == msg.sender, "FishdomMarket: Not owner");
        _;
    }
}
