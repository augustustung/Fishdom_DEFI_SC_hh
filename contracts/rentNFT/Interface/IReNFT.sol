// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IReNft is IERC721Receiver, IERC1155Receiver {
    event Lent(
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint8 lentAmount,
        uint256 lendingId,
        address indexed lenderAddress,
        uint8 maxRentDuration,
        bytes4 dailyRentPrice,
        bytes4 nftPrice,
        bool isERC721,
        string paymentToken
    );

    event Rented(
        uint256 lendingId,
        address indexed renterAddress,
        uint8 rentDuration,
        uint32 rentedAt
    );

    event Returned(uint256 indexed lendingId, uint32 returnedAt);

    event CollateralClaimed(uint256 indexed lendingId, uint32 claimedAt);

    event LendingStopped(uint256 indexed lendingId, uint32 stoppedAt);

    /**
     * @dev sends your NFT to ReNFT contract, which acts as an escrow
     * between the lender and the renter
     */
    function lend(
        address _nft,
        uint256 _tokenId,
        uint256 _lendAmount,
        uint8 _maxRentDuration,
        bytes4 _dailyRentPrice,
        bytes4 _nftPrice,
        string memory _paymentToken
    ) external;

    /**
     * @dev renter sends rentDuration * dailyRentPrice
     * to cover for the potentially full cost of renting. They also
     * must send the collateral (nft price set by the lender in lend)
     */
    function rent(
        address _nft,
        uint256 _tokenId,
        uint256 _lendingId,
        uint8 _rentDuration
    ) external;

    /**
     * @dev claim collateral on rentals that are past their due date
     */
    function claimCollateral(
        address _nft,
        uint256 _tokenId,
        uint256 _lendingId
    ) external;

    /**
     * @dev renters call this to return the rented NFT before the
     * deadline. If they fail to do so, they will lose the posted
     * collateral
     */
    function returnIt(
        address _nft,
        uint256 _tokenId,
        uint256 _lendingId
    ) external;

    /**
     * @dev stop lending releases the NFT from escrow and sends it back
     * to the lender
     */
    function stopLending(
        address _nft,
        uint256 _tokenId,
        uint256 _lendingId
    ) external;
}
