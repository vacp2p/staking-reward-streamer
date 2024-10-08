// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { TrustedCodehashAccess } from "./access/TrustedCodehashAccess.sol";
import { IStakeManager } from "./IStakeManager.sol";

// Rewards Streamer with Multiplier Points
contract RewardsStreamerMP is IStakeManager, TrustedCodehashAccess, ReentrancyGuard {
    error StakeManager__TransferFailed();
    error StakeManager__CannotRestakeWithLockedFunds();

    IERC20 public immutable STAKE_TOKEN;
    IERC20 public immutable REWARD_TOKEN;

    uint256 public constant SCALE_FACTOR = 1e18;
    uint256 public constant MP_APY = 1e18;

    uint256 public constant MIN_LOCKUP_PERIOD = 90 days;
    uint256 public constant MAX_LOCKUP_PERIOD = 4 * 365 days;
    uint256 public constant MAX_MULTIPLIER = 4;

    uint256 public totalStaked;
    uint256 public totalMP;
    uint256 public potentialMP;
    uint256 public rewardIndex;
    uint256 public accountedRewards;
    uint256 public lastMPUpdatedTime;

    struct UserInfo {
        uint256 stakedBalance;
        uint256 userRewardIndex;
        uint256 userMP;
        uint256 userPotentialMP;
        uint256 lastMPUpdateTime;
        uint256 lockUntil;
    }

    mapping(address account => UserInfo data) public users;

    constructor(address _stakingToken, address _rewardToken) {
        STAKE_TOKEN = IERC20(_stakingToken);
        REWARD_TOKEN = IERC20(_rewardToken);
        lastMPUpdatedTime = block.timestamp;
    }

    function stake(uint256 _amount, uint256 _seconds) external onlyTrustedCodehash nonReentrant {
        if (_amount == 0) {
            revert StakeManager__StakeIsTooLow();
        }

        if (_seconds != 0 && (_seconds < MIN_LOCKUP_PERIOD || _seconds > MAX_LOCKUP_PERIOD)) {
            revert StakeManager__InvalidLockTime();
        }

        _updateGlobalState();
        updateUserMP(msg.sender);

        UserInfo storage user = users[msg.sender];
        if (user.lockUntil != 0 && user.lockUntil > block.timestamp) {
            revert StakeManager__CannotRestakeWithLockedFunds();
        }

        uint256 userRewards = calculateUserRewards(msg.sender);
        if (userRewards > 0) {
            distributeRewards(msg.sender, userRewards);
        }

        bool success = STAKE_TOKEN.transferFrom(msg.sender, address(this), _amount);
        if (!success) {
            revert StakeManager__TransferFailed();
        }

        user.stakedBalance += _amount;
        totalStaked += _amount;

        uint256 initialMP = _amount;
        uint256 userPotentialMP = _amount * MAX_MULTIPLIER;

        if (_seconds != 0) {
            uint256 lockMultiplier = (_seconds * MAX_MULTIPLIER * SCALE_FACTOR) / MAX_LOCKUP_PERIOD;
            lockMultiplier = lockMultiplier / SCALE_FACTOR;
            initialMP += (_amount * lockMultiplier);
            userPotentialMP += (_amount * lockMultiplier);
            user.lockUntil = block.timestamp + _seconds;
        } else {
            user.lockUntil = 0;
        }

        user.userMP += initialMP;
        totalMP += initialMP;

        user.userPotentialMP += userPotentialMP;
        potentialMP += userPotentialMP;

        user.userRewardIndex = rewardIndex;
        user.lastMPUpdateTime = block.timestamp;
    }

    function unstake(uint256 _amount) external onlyTrustedCodehash nonReentrant {
        UserInfo storage user = users[msg.sender];
        if (_amount > user.stakedBalance) {
            revert StakeManager__InsufficientFunds();
        }

        if (block.timestamp < user.lockUntil) {
            revert StakeManager__FundsLocked();
        }

        _updateGlobalState();
        updateUserMP(msg.sender);

        uint256 userRewards = calculateUserRewards(msg.sender);
        if (userRewards > 0) {
            distributeRewards(msg.sender, userRewards);
        }

        uint256 previousStakedBalance = user.stakedBalance;
        user.stakedBalance -= _amount;
        totalStaked -= _amount;

        uint256 amountRatio = (_amount * SCALE_FACTOR) / previousStakedBalance;
        uint256 mpToReduce = (user.userMP * amountRatio) / SCALE_FACTOR;
        uint256 potentialMPToReduce = (user.userPotentialMP * amountRatio) / SCALE_FACTOR;

        user.userMP -= mpToReduce;
        user.userPotentialMP -= potentialMPToReduce;
        totalMP -= mpToReduce;
        potentialMP -= potentialMPToReduce;

        bool success = STAKE_TOKEN.transfer(msg.sender, _amount);
        if (!success) {
            revert StakeManager__TransferFailed();
        }

        user.userRewardIndex = rewardIndex;
    }

    function lock(uint256 _secondsIncrease) external onlyTrustedCodehash {
        //TODO: increase lock time
        revert("Not implemented");
    }

    function exit() external returns (bool _leaveAccepted) {
        if (!isTrustedCodehash(msg.sender.codehash)) {
            //case owner removed access from a class of StakeVault,. they might exit
            delete user[msg.sender];
            return true;
        } else {
            //TODO: handle other cases
            //TODO: handle update/migration case
            //TODO: handle emergency exit
            revert("Not implemented");
        }
    }

    function acceptUpdate() external onlyTrustedCodehash returns (address _migrated) {
        //TODO: handle update/migration
        revert("Not implemented");
    }

    function _updateGlobalState() internal {
        updateGlobalMP();
        updateRewardIndex();
    }

    function updateGlobalState() external {
        _updateGlobalState();
    }

    function updateGlobalMP() internal {
        if (potentialMP == 0) {
            lastMPUpdatedTime = block.timestamp;
            return;
        }

        uint256 currentTime = block.timestamp;
        uint256 timeDiff = currentTime - lastMPUpdatedTime;
        if (timeDiff == 0) {
            return;
        }

        uint256 accruedMP = calculateMP(totalStaked, timeDiff);
        if (accruedMP > potentialMP) {
            accruedMP = potentialMP;
        }

        // Adjust rewardIndex before updating totalMP
        uint256 previousTotalWeight = totalStaked + totalMP;
        totalMP += accruedMP;
        uint256 newTotalWeight = totalStaked + totalMP;

        if (previousTotalWeight != 0 && newTotalWeight != previousTotalWeight) {
            rewardIndex = (rewardIndex * previousTotalWeight) / newTotalWeight;
        }

        potentialMP -= accruedMP;
        lastMPUpdatedTime = currentTime;
    }

    function updateRewardIndex() internal {
        uint256 totalWeight = totalStaked + totalMP;
        if (totalWeight == 0) {
            return;
        }

        uint256 rewardBalance = REWARD_TOKEN.balanceOf(address(this));
        uint256 newRewards = rewardBalance > accountedRewards ? rewardBalance - accountedRewards : 0;

        if (newRewards > 0) {
            rewardIndex += (newRewards * SCALE_FACTOR) / totalWeight;
            accountedRewards += newRewards;
        }
    }

    function updateUserMP(address _vault) internal {
        UserInfo storage user = users[_vault];

        if (user.userPotentialMP == 0 || user.stakedBalance == 0) {
            user.lastMPUpdateTime = block.timestamp;
            return;
        }

        uint256 timeDiff = block.timestamp - user.lastMPUpdateTime;
        if (timeDiff == 0) {
            return;
        }

        uint256 accruedMP = calculateMP(user.stakedBalance, timeDiff);

        if (accruedMP > user.userPotentialMP) {
            accruedMP = user.userPotentialMP;
        }

        user.userPotentialMP -= accruedMP;
        user.userMP += accruedMP;

        user.lastMPUpdateTime = block.timestamp;
    }

    function calculateUserRewards(address _vault) public view returns (uint256) {
        UserInfo storage user = users[_vault];
        uint256 userWeight = user.stakedBalance + user.userMP;
        uint256 deltaRewardIndex = rewardIndex - user.userRewardIndex;
        return (userWeight * deltaRewardIndex) / SCALE_FACTOR;
    }

    function distributeRewards(address to, uint256 amount) internal {
        uint256 rewardBalance = REWARD_TOKEN.balanceOf(address(this));
        // If amount is higher than the contract's balance (for rounding error), transfer the balance.
        if (amount > rewardBalance) {
            amount = rewardBalance;
        }

        accountedRewards -= amount;

        bool success = REWARD_TOKEN.transfer(to, amount);
        if (!success) {
            revert StakeManager__TransferFailed();
        }
    }

    function calculateMP(uint256 _balance, uint256 _deltaTime) public pure returns (uint256) {
        return (_deltaTime * _balance * MP_APY) / (365 days * SCALE_FACTOR);
    }

    function getStakedBalance(address _vault) external view returns (uint256 _balance) {
        return users[_vault].stakedBalance;
    }

    function getPendingRewards(address _vault) external view returns (uint256) {
        return calculateUserRewards(_vault);
    }

    function getUserInfo(address _vault) external view returns (UserInfo memory) {
        return users[_vault];
    }

    function totalSupplyMinted() external view returns (uint256 _totalSupply) {
        return totalStaked + totalMP;
    }

    function totalSupply() external view returns (uint256 _totalSupply) {
        return totalStaked + totalMP + potentialMP;
    }

    function pendingReward() external view returns (uint256 _pendingReward) {
        return STAKE_TOKEN().balanceOf(address(this)) - accountedRewards;
    }
}
