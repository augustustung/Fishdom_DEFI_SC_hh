// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./token/IFishdomToken.sol";

contract FishdomStaking {
    uint256 constant dateToSecond = 10; // MUST CHANGE TO 24 * 60 * 60
    uint256 constant yearToDate = 365;

    struct Package {
        uint256 apr;
        uint256 duration;
        uint8 id;
    }

    /**
     * @param owner: address of user staked
     * @param timestamp: last time check
     * @param amount: amount that user spent
     */
    struct Stake {
        uint256 stakeId;
        address owner;
        uint32 timestamp;
        uint256 amount;
        uint256 duration;
        uint256 apr;
    }

    event Staked(
        uint256 indexed stakeId,
        address indexed owner,
        uint256 amount,
        uint256 duration,
        uint256 apr
    );

    event Unstaked(
        uint256 indexed stakeId,
        address indexed owner,
        uint256 claimed
    );

    event Claimed(
        uint256 indexed stakeId,
        address indexed owner,
        uint256 indexed amount
    );

    IFishdomToken FishdomToken;
    address _owner;

    // maps address of user to stake
    Stake[] vault;
    Package[4] packages;

    constructor(address token_) {
        FishdomToken = IFishdomToken(token_);
        _owner = msg.sender;
    }

    function initialize() external onlyOwner {
        packages[0].apr = 100;
        packages[0].duration = 30;
        packages[0].id = 0;
        packages[1].apr = 138;
        packages[1].duration = 90;
        packages[1].id = 1;
        packages[2].apr = 220;
        packages[2].duration = 180;
        packages[2].id = 2;
        packages[3].apr = 5;
        packages[3].duration = 0;
        packages[3].id = 3;
    }

    function getListPackage() public view returns (Package[4] memory) {
        return packages;
    }

    function _calculateEarned(uint256 stakingId, bool isGetAll)
        internal
        view
        returns (uint256)
    {
        Stake memory ownerStaking = vault[stakingId];
        uint256 _apr = ownerStaking.apr;
        if (ownerStaking.duration == 0) {
            // số ngày lãi
            uint256 stakedTimeClaim = (uint32(block.timestamp) -
                ownerStaking.timestamp) / (1 * dateToSecond);
            // tiền lãi theo ngày * số ngày
            uint256 earned = (ownerStaking.amount * _apr * stakedTimeClaim) /
                (yearToDate * 100); // (aprPercent * time) / (1 year  * 100)

            return isGetAll ? ownerStaking.amount + earned : earned;
        } else {
            // tiền lãi theo ngày * số ngày
            uint256 earned = (ownerStaking.amount *
                _apr *
                ownerStaking.duration) / (yearToDate * 100);
            return ownerStaking.amount + earned;
        }
    }

    /**
     * @param _stakingId: 0 fixed - 30, 1 fixed - 90, 2 fixed - 180, 3: unfixed
     * @param _amount: amount user spent
     */
    function stake(uint8 _stakingId, uint256 _amount) external {
        Package memory finalPackage = packages[_stakingId];

        uint256 allowance = FishdomToken.allowance(msg.sender, address(this));
        require(allowance >= _amount, "FishdomStaking: Over allowance");
        FishdomToken.transferFrom(msg.sender, address(this), _amount);

        uint256 newStakeId = vault.length;
        vault.push(
            Stake(
                newStakeId,
                msg.sender,
                uint32(block.timestamp),
                _amount,
                finalPackage.duration,
                finalPackage.apr
            )
        );
        emit Staked(
            newStakeId,
            msg.sender,
            _amount,
            finalPackage.duration,
            finalPackage.apr
        );
    }

    function claim(uint256 _stakingId) external {
        Stake memory staked = vault[_stakingId];
        require(msg.sender == staked.owner, "Ownable: Not owner");
        uint256 stakeDuration = staked.duration;
        if (stakeDuration != 0) {
            uint32 lastTimeCheck = staked.timestamp;
            require(
                uint32(block.timestamp) >=
                    (lastTimeCheck + (stakeDuration * dateToSecond)),
                "Staking locked"
            );
        }
        uint256 earned = _calculateEarned(_stakingId, false);
        if (earned > 0) {
            if (stakeDuration != 0) {
                earned += staked.amount;
                delete vault[_stakingId];
            } else {
                vault[_stakingId].timestamp = uint32(block.timestamp);
            }
            FishdomToken.transfer(msg.sender, earned);
            emit Claimed(_stakingId, msg.sender, earned);
        }
    }

    function unstake(uint256 _stakingId) external {
        Stake memory staked = vault[_stakingId];
        require(staked.duration == 0, "Cannot unstake fixed staking package");
        require(msg.sender == staked.owner, "Ownable: Not owner");
        uint256 earned = _calculateEarned(_stakingId, true);
        delete vault[_stakingId];
        emit Unstaked(_stakingId, msg.sender, earned);
        FishdomToken.transfer(msg.sender, earned);
    }

    function getEarned(uint256 stakingId) external view returns (uint256) {
        return _calculateEarned(stakingId, true);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        _owner = newOwner;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "FishdomStaking: Not owner");
        _;
    }
}
