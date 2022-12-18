// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import "./Interface/IResolver.sol";
import "./Interface/IReNFT.sol";

contract ReNFT is IReNft, ERC721Holder, ERC1155Receiver, ERC1155Holder {
    IResolver private resolver;
    address private admin;
    address payable private beneficiary;
    uint256 private lendingId = 1;
    bool public paused = false;

    // in bps. so 1000 => 1%
    uint256 public rentFee = 0;

    uint256 private constant SECONDS_IN_DAY = 86400;

    // single storage slot: address - 160 bits, 168, 200, 232, 240, 248
    struct Lending {
        address payable lenderAddress;
        uint8 maxRentDuration;
        bytes4 dailyRentPrice;
        bytes4 nftPrice;
        uint8 lentAmount;
        string paymentToken;
    }

    // single storage slot: 160 bits, 168, 200
    struct Renting {
        address payable renterAddress;
        uint8 rentDuration;
        uint32 rentedAt;
    }

    struct LendingRenting {
        Lending lending;
        Renting renting;
    }

    mapping(bytes32 => LendingRenting) private lendingRenting;

    struct CallData {
        address nft;
        uint256 tokenId;
        uint256 lentAmount;
        uint8 maxRentDuration;
        bytes4 dailyRentPrice;
        bytes4 nftPrice;
        uint256 lendingId;
        uint8 rentDuration;
        string paymentToken;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "ReNFT::not admin");
        _;
    }

    modifier notPaused() {
        require(!paused, "ReNFT::paused");
        _;
    }

    constructor(
        address _resolver,
        address payable _beneficiary,
        address _admin
    ) {
        ensureIsNotZeroAddr(_resolver);
        ensureIsNotZeroAddr(_beneficiary);
        ensureIsNotZeroAddr(_admin);
        resolver = IResolver(_resolver);
        beneficiary = _beneficiary;
        admin = _admin;
    }

    function bundleCall(function(CallData memory) _handler, CallData memory _cd)
        private
    {
        _handler(_cd);
    }

    // lend, rent, return, stop, claim
    function lend(
        address _nft,
        uint256 _tokenId,
        uint256 _lendAmount,
        uint8 _maxRentDuration,
        bytes4 _dailyRentPrice,
        bytes4 _nftPrice,
        string memory _paymentToken
    ) external notPaused {
        bundleCall(
            handleLend,
            createLendCallData(
                _nft,
                _tokenId,
                _lendAmount,
                _maxRentDuration,
                _dailyRentPrice,
                _nftPrice,
                _paymentToken
            )
        );
    }

    function rent(
        address _nft,
        uint256 _tokenId,
        uint256 _lendingId,
        uint8 _rentDuration
    ) external override notPaused {
        bundleCall(
            handleRent,
            createRentCallData(_nft, _tokenId, _lendingId, _rentDuration)
        );
    }

    function claimCollateral(
        address _nft,
        uint256 _tokenId,
        uint256 _lendingId
    ) external {
        bundleCall(
            handleClaimCollateral,
            createActionCallData(_nft, _tokenId, _lendingId)
        );
    }

    function returnIt(
        address _nft,
        uint256 _tokenId,
        uint256 _lendingId
    ) external override notPaused {
        bundleCall(
            handleReturn,
            createActionCallData(_nft, _tokenId, _lendingId)
        );
    }

    function stopLending(
        address _nft,
        uint256 _tokenId,
        uint256 _lendingId
    ) external override notPaused {
        bundleCall(
            handleStopLending,
            createActionCallData(_nft, _tokenId, _lendingId)
        );
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function takeFee(uint256 _rent, address _paymentToken)
        private
        returns (uint256 fee)
    {
        fee = _rent * rentFee;
        fee /= 10000;
        ERC20 paymentToken = ERC20(_paymentToken);
        paymentToken.transfer(beneficiary, fee);
    }

    function distributePayments(
        LendingRenting storage _lendingRenting,
        uint256 _secondsSinceRentStart
    ) private {
        address paymentToken = resolver.getPaymentToken(
            _lendingRenting.lending.paymentToken
        );
        ensureIsNotZeroAddr(paymentToken);
        uint256 decimals = ERC20(paymentToken).decimals();

        uint256 scale = 10**decimals;
        uint256 nftPrice = _lendingRenting.lending.lentAmount *
            unpackPrice(_lendingRenting.lending.nftPrice, scale);
        uint256 rentPrice = unpackPrice(
            _lendingRenting.lending.dailyRentPrice,
            scale
        );
        uint256 totalRenterPmtWoCollateral = rentPrice *
            _lendingRenting.renting.rentDuration;
        uint256 sendLenderAmt = (_secondsSinceRentStart * rentPrice) /
            SECONDS_IN_DAY;
        require(
            totalRenterPmtWoCollateral > 0,
            "ReNFT::total payment wo collateral is zero"
        );
        require(sendLenderAmt > 0, "ReNFT::lender payment is zero");
        uint256 sendRenterAmt = totalRenterPmtWoCollateral - sendLenderAmt;

        uint256 takenFee = takeFee(sendLenderAmt, paymentToken);

        sendLenderAmt -= takenFee;
        sendRenterAmt += nftPrice;

        ERC20(paymentToken).transfer(
            _lendingRenting.lending.lenderAddress,
            sendLenderAmt
        );
        ERC20(paymentToken).transfer(
            _lendingRenting.renting.renterAddress,
            sendRenterAmt
        );
    }

    function distributeClaimPayment(LendingRenting memory _lendingRenting)
        private
    {
        address paymentTokenAddress = resolver.getPaymentToken(
            _lendingRenting.lending.paymentToken
        );
        ensureIsNotZeroAddr(paymentTokenAddress);
        ERC20 paymentToken = ERC20(paymentTokenAddress);

        uint256 decimals = paymentToken.decimals();
        uint256 scale = 10**decimals;
        uint256 nftPrice = _lendingRenting.lending.lentAmount *
            unpackPrice(_lendingRenting.lending.nftPrice, scale);
        uint256 rentPrice = unpackPrice(
            _lendingRenting.lending.dailyRentPrice,
            scale
        );
        uint256 maxRentPayment = rentPrice *
            _lendingRenting.renting.rentDuration;
        uint256 takenFee = takeFee(maxRentPayment, paymentTokenAddress);
        uint256 finalAmt = maxRentPayment + nftPrice;

        require(maxRentPayment > 0, "ReNFT::collateral plus rent is zero");

        paymentToken.transfer(
            _lendingRenting.lending.lenderAddress,
            finalAmt - takenFee
        );
    }

    function safeTransfer(
        CallData memory _cd,
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 _lentAmount
    ) private {
        if (is721(_cd.nft)) {
            IERC721(_cd.nft).transferFrom(_from, _to, _cd.tokenId);
        } else if (is1155(_cd.nft)) {
            IERC1155(_cd.nft).safeTransferFrom(
                _from,
                _to,
                _tokenId,
                _lentAmount,
                ""
            );
        } else {
            revert("ReNFT::unsupported token type");
        }
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function handleLend(CallData memory _cd) private {
        ensureIsLendable(_cd);
        LendingRenting storage item = lendingRenting[
            keccak256(abi.encodePacked(_cd.nft, _cd.tokenId, lendingId))
        ];
        ensureIsNull(item.lending);
        ensureIsNull(item.renting);
        bool nftIs721 = is721(_cd.nft);
        item.lending = Lending({
            lenderAddress: payable(msg.sender),
            lentAmount: nftIs721 ? 1 : uint8(_cd.lentAmount),
            maxRentDuration: _cd.maxRentDuration,
            dailyRentPrice: _cd.dailyRentPrice,
            nftPrice: _cd.nftPrice,
            paymentToken: _cd.paymentToken
        });
        emit Lent(
            _cd.nft,
            _cd.tokenId,
            nftIs721 ? 1 : uint8(_cd.lentAmount),
            lendingId,
            msg.sender,
            _cd.maxRentDuration,
            _cd.dailyRentPrice,
            _cd.nftPrice,
            nftIs721,
            _cd.paymentToken
        );
        lendingId++;
        safeTransfer(
            _cd,
            msg.sender,
            address(this),
            _cd.tokenId,
            _cd.lentAmount
        );
    }

    function handleRent(CallData memory _cd) private {
        LendingRenting storage item = lendingRenting[
            keccak256(abi.encodePacked(_cd.nft, _cd.tokenId, _cd.lendingId))
        ];

        ensureIsNotNull(item.lending);
        ensureIsNull(item.renting);
        ensureIsRentable(item.lending, _cd, msg.sender);

        address paymentToken = resolver.getPaymentToken(
            item.lending.paymentToken
        );
        ensureIsNotZeroAddr(paymentToken);
        uint256 decimals = ERC20(paymentToken).decimals();

        {
            uint256 scale = 10**decimals;
            uint256 rentPrice = _cd.rentDuration *
                unpackPrice(item.lending.dailyRentPrice, scale);
            uint256 nftPrice = item.lending.lentAmount *
                unpackPrice(item.lending.nftPrice, scale);

            require(rentPrice > 0, "ReNFT::rent price is zero");
            require(nftPrice > 0, "ReNFT::nft price is zero");
            ERC20(paymentToken).transferFrom(
                msg.sender,
                address(this),
                rentPrice + nftPrice
            );
        }

        item.renting.renterAddress = payable(msg.sender);
        item.renting.rentDuration = _cd.rentDuration;
        item.renting.rentedAt = uint32(block.timestamp);

        emit Rented(
            _cd.lendingId,
            msg.sender,
            _cd.rentDuration,
            item.renting.rentedAt
        );

        safeTransfer(
            _cd,
            address(this),
            msg.sender,
            _cd.tokenId,
            _cd.lentAmount
        );
    }

    function handleClaimCollateral(CallData memory _cd) private {
        LendingRenting storage item = lendingRenting[
            keccak256(abi.encodePacked(_cd.nft, _cd.tokenId, _cd.lendingId))
        ];

        ensureIsNotNull(item.lending);
        ensureIsNotNull(item.renting);
        ensureIsClaimable(item.renting, block.timestamp);

        distributeClaimPayment(item);

        emit CollateralClaimed(_cd.lendingId, uint32(block.timestamp));

        delete item.lending;
        delete item.renting;
    }

    function handleReturn(CallData memory _cd) private {
        LendingRenting storage item = lendingRenting[
            keccak256(abi.encodePacked(_cd.nft, _cd.tokenId, _cd.lendingId))
        ];

        ensureIsNotNull(item.lending);
        ensureIsReturnable(item.renting, msg.sender, block.timestamp);

        uint256 secondsSinceRentStart = block.timestamp - item.renting.rentedAt;
        distributePayments(item, secondsSinceRentStart);

        emit Returned(_cd.lendingId, uint32(block.timestamp));

        delete item.renting;

        safeTransfer(
            _cd,
            msg.sender,
            address(this),
            _cd.tokenId,
            _cd.lentAmount
        );
    }

    function handleStopLending(CallData memory _cd) private {
        LendingRenting storage item = lendingRenting[
            keccak256(abi.encodePacked(_cd.nft, _cd.tokenId, _cd.lendingId))
        ];

        ensureIsNotNull(item.lending);
        ensureIsNull(item.renting);
        ensureIsStoppable(item.lending, msg.sender);

        emit LendingStopped(_cd.lendingId, uint32(block.timestamp));

        delete item.lending;

        safeTransfer(
            _cd,
            address(this),
            msg.sender,
            _cd.tokenId,
            _cd.lentAmount
        );
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function is721(address _nft) private view returns (bool) {
        return IERC165(_nft).supportsInterface(type(IERC721).interfaceId);
    }

    function is1155(address _nft) private view returns (bool) {
        return IERC165(_nft).supportsInterface(type(IERC1155).interfaceId);
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function createLendCallData(
        address _nft,
        uint256 _tokenId,
        uint256 _lendAmount,
        uint8 _maxRentDuration,
        bytes4 _dailyRentPrice,
        bytes4 _nftPrice,
        string memory _paymentToken
    ) private pure returns (CallData memory cd) {
        return
            CallData({
                nft: _nft,
                tokenId: _tokenId,
                lentAmount: _lendAmount,
                lendingId: 0,
                rentDuration: 0,
                maxRentDuration: _maxRentDuration,
                dailyRentPrice: _dailyRentPrice,
                nftPrice: _nftPrice,
                paymentToken: _paymentToken
            });
    }

    function createRentCallData(
        address _nft,
        uint256 _tokenId,
        uint256 _lendingId,
        uint8 _rentDuration
    ) private pure returns (CallData memory cd) {
        return
            CallData({
                nft: _nft,
                tokenId: _tokenId,
                lentAmount: 0,
                lendingId: _lendingId,
                rentDuration: _rentDuration,
                maxRentDuration: 0,
                dailyRentPrice: 0,
                nftPrice: 0,
                paymentToken: ""
            });
    }

    function createActionCallData(
        address _nft,
        uint256 _tokenId,
        uint256 _lendingId
    ) private pure returns (CallData memory cd) {
        return
            CallData({
                nft: _nft,
                tokenId: _tokenId,
                lentAmount: 0,
                lendingId: _lendingId,
                rentDuration: 0,
                maxRentDuration: 0,
                dailyRentPrice: 0,
                nftPrice: 0,
                paymentToken: ""
            });
    }

    function unpackPrice(bytes4 _price, uint256 _scale)
        private
        pure
        returns (uint256)
    {
        ensureIsUnpackablePrice(_price, _scale);

        uint16 whole = uint16(bytes2(_price));
        uint16 decimal = uint16(bytes2(_price << 16));
        uint256 decimalScale = _scale / 10000;

        if (whole > 9999) {
            whole = 9999;
        }
        if (decimal > 9999) {
            decimal = 9999;
        }

        uint256 w = whole * _scale;
        uint256 d = decimal * decimalScale;
        uint256 price = w + d;

        return price;
    }

    function sliceArr(
        uint256[] memory _arr,
        uint256 _fromIx,
        uint256 _toIx,
        uint256 _arrOffset
    ) private pure returns (uint256[] memory r) {
        r = new uint256[](_toIx - _fromIx);
        for (uint256 i = _fromIx; i < _toIx; i++) {
            r[i - _fromIx] = _arr[i - _arrOffset];
        }
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function ensureIsNotZeroAddr(address _addr) private pure {
        require(_addr != address(0), "ReNFT::zero address");
    }

    function ensureIsZeroAddr(address _addr) private pure {
        require(_addr == address(0), "ReNFT::not a zero address");
    }

    function ensureIsNull(Lending memory _lending) private pure {
        ensureIsZeroAddr(_lending.lenderAddress);
        require(_lending.maxRentDuration == 0, "ReNFT::duration not zero");
        require(_lending.dailyRentPrice == 0, "ReNFT::rent price not zero");
        require(_lending.nftPrice == 0, "ReNFT::nft price not zero");
    }

    function ensureIsNotNull(Lending memory _lending) private pure {
        ensureIsNotZeroAddr(_lending.lenderAddress);
        require(_lending.maxRentDuration != 0, "ReNFT::duration zero");
        require(_lending.dailyRentPrice != 0, "ReNFT::rent price is zero");
        require(_lending.nftPrice != 0, "ReNFT::nft price is zero");
    }

    function ensureIsNull(Renting memory _renting) private pure {
        ensureIsZeroAddr(_renting.renterAddress);
        require(_renting.rentDuration == 0, "ReNFT::duration not zero");
        require(_renting.rentedAt == 0, "ReNFT::rented at not zero");
    }

    function ensureIsNotNull(Renting memory _renting) private pure {
        ensureIsNotZeroAddr(_renting.renterAddress);
        require(_renting.rentDuration != 0, "ReNFT::duration is zero");
        require(_renting.rentedAt != 0, "ReNFT::rented at is zero");
    }

    function ensureIsLendable(CallData memory _cd) private pure {
        require(_cd.lentAmount > 0, "ReNFT::lend amount is zero");
        require(_cd.lentAmount <= type(uint8).max, "ReNFT::not uint8");
        require(_cd.maxRentDuration > 0, "ReNFT::duration is zero");
        require(_cd.maxRentDuration <= type(uint8).max, "ReNFT::not uint8");
        require(uint32(_cd.dailyRentPrice) > 0, "ReNFT::rent price is zero");
        require(uint32(_cd.nftPrice) > 0, "ReNFT::nft price is zero");
    }

    function ensureIsRentable(
        Lending memory _lending,
        CallData memory _cd,
        address _msgSender
    ) private pure {
        require(
            _msgSender != _lending.lenderAddress,
            "ReNFT::cant rent own nft"
        );
        require(_cd.rentDuration <= type(uint8).max, "ReNFT::not uint8");
        require(_cd.rentDuration > 0, "ReNFT::duration is zero");
        require(
            _cd.rentDuration <= _lending.maxRentDuration,
            "ReNFT::rent duration exceeds allowed max"
        );
    }

    function ensureIsReturnable(
        Renting memory _renting,
        address _msgSender,
        uint256 _blockTimestamp
    ) private pure {
        require(_renting.renterAddress == _msgSender, "ReNFT::not renter");
        require(
            !isPastReturnDate(_renting, _blockTimestamp),
            "ReNFT::past return date"
        );
    }

    function ensureIsStoppable(Lending memory _lending, address _msgSender)
        private
        pure
    {
        require(_lending.lenderAddress == _msgSender, "ReNFT::not lender");
    }

    function ensureIsClaimable(Renting memory _renting, uint256 _blockTimestamp)
        private
        pure
    {
        require(
            isPastReturnDate(_renting, _blockTimestamp),
            "ReNFT::return date not passed"
        );
    }

    function ensureIsUnpackablePrice(bytes4 _price, uint256 _scale)
        private
        pure
    {
        require(uint32(_price) > 0, "ReNFT::invalid price");
        require(_scale >= 10000, "ReNFT::invalid scale");
    }

    function ensureTokenNotSentinel(uint8 _paymentIx) private pure {
        require(_paymentIx > 0, "ReNFT::token is sentinel");
    }

    function isPastReturnDate(Renting memory _renting, uint256 _now)
        private
        pure
        returns (bool)
    {
        require(_now > _renting.rentedAt, "ReNFT::now before rented");
        return
            _now - _renting.rentedAt > _renting.rentDuration * SECONDS_IN_DAY;
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function setRentFee(uint256 _rentFee) external onlyAdmin {
        require(_rentFee < 10000, "ReNFT::fee exceeds 100pct");
        rentFee = _rentFee;
    }

    function setBeneficiary(address payable _newBeneficiary)
        external
        onlyAdmin
    {
        beneficiary = _newBeneficiary;
    }

    function setPaused(bool _paused) external onlyAdmin {
        paused = _paused;
    }
}
