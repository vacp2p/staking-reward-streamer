// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract RewardsStreamer is ReentrancyGuard, Ownable {
    error StakingManager__AmountCannotBeZero();
    error StakingManager__TransferFailed();
    error StakingManager__InsufficientBalance();

    IERC20 public immutable STAKING_TOKEN;
    IERC20 public immutable REWARD_TOKEN;

    uint256 public constant SCALE_FACTOR = 1e18;

    uint256 public totalStaked;
    uint256 public rewardIndex;
    uint256 public accountedRewards;

    struct UserInfo {
        uint256 stakedBalance;
        uint256 userRewardIndex;
    }

    mapping(address account => UserInfo data) public users;

    /**
     * @dev The number of reward tokens distributed per block.
     */
    uint256 public rewardsPerBlock;

    /**
     * @dev The block number at which the last reward calculation was performed.
     */
    uint256 public lastRewardBlock;

    /**
     * @dev The block number at which the current reward rate ends.
     */
    uint256 public rewardEndBlock;

    constructor(address _stakingToken, address _rewardToken, uint256 _rewardsPerBlock) Ownable() {
        STAKING_TOKEN = IERC20(_stakingToken);
        REWARD_TOKEN = IERC20(_rewardToken);
        rewardsPerBlock = _rewardsPerBlock;
        lastRewardBlock = block.number;
    }

    /**
     * @dev Calculates the current reward index based on the number of blocks
     * since the last update and the rewards per block. This function does not
     * modify the state and is used to determine the most up-to-date reward index
     * for calculating user rewards.
     * @return The current reward index.
     */
    function currentRewardIndex() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardIndex;
        }

        uint256 blocksSinceLastUpdate = block.number - lastRewardBlock;
        uint256 applicableBlocks = blocksSinceLastUpdate;

        if (block.number > rewardEndBlock) {
            applicableBlocks = rewardEndBlock - lastRewardBlock;
        }

        uint256 newRewards = applicableBlocks * rewardsPerBlock;
        return rewardIndex + (newRewards * SCALE_FACTOR) / totalStaked;
    }

    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) {
            revert StakingManager__AmountCannotBeZero();
        }

        updateRewardIndex();

        UserInfo storage user = users[msg.sender];
        uint256 userRewards = calculateUserRewards(msg.sender);
        if (userRewards > 0) {
            distributeRewards(msg.sender, userRewards);
        }

        bool success = STAKING_TOKEN.transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert StakingManager__TransferFailed();
        }

        user.stakedBalance += amount;
        totalStaked += amount;
        user.userRewardIndex = rewardIndex;
    }

    function unstake(uint256 amount) external nonReentrant {
        UserInfo storage user = users[msg.sender];
        if (amount > user.stakedBalance) {
            revert StakingManager__InsufficientBalance();
        }

        updateRewardIndex();

        uint256 userRewards = calculateUserRewards(msg.sender);
        if (userRewards > 0) {
            distributeRewards(msg.sender, userRewards);
        }

        user.stakedBalance -= amount;
        totalStaked -= amount;

        bool success = STAKING_TOKEN.transfer(msg.sender, amount);
        if (!success) {
            revert StakingManager__TransferFailed();
        }

        user.userRewardIndex = rewardIndex;
    }

    /**
     * @dev Updates the reward index and accounted rewards based on the current
     * block number. This function is called before any state-modifying operations
     * to ensure that the reward calculations are up-to-date. It updates the
     * `rewardIndex` to reflect the latest calculated value and increments
     * `accountedRewards` with the new rewards accrued since the last update.
     */
    function updateRewardIndex() internal {
        if (totalStaked == 0 || block.number >= rewardEndBlock) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 blocksSinceLastUpdate = block.number - lastRewardBlock;
        uint256 applicableBlocks = blocksSinceLastUpdate;

        if (block.number > rewardEndBlock) {
            applicableBlocks = rewardEndBlock - lastRewardBlock;
        }

        uint256 newRewards = applicableBlocks * rewardsPerBlock;

        // Update the rewardIndex to the current calculated value
        rewardIndex = rewardIndex + (newRewards * SCALE_FACTOR) / totalStaked;

        // Update accountedRewards with the new rewards
        accountedRewards += newRewards;

        lastRewardBlock = block.number;
    }

    function getStakedBalance(address userAddress) public view returns (uint256) {
        return users[userAddress].stakedBalance;
    }

    function getPendingRewards(address userAddress) public view returns (uint256) {
        return calculateUserRewards(userAddress);
    }

    function calculateUserRewards(address userAddress) public view returns (uint256) {
        UserInfo storage user = users[userAddress];
        uint256 currentIndex = currentRewardIndex();
        return (user.stakedBalance * (currentIndex - user.userRewardIndex)) / SCALE_FACTOR;
    }

    // send the rewards and updates accountedRewards
    function distributeRewards(address to, uint256 amount) internal {
        uint256 rewardBalance = REWARD_TOKEN.balanceOf(address(this));
        // If amount is higher than the contract's balance (for rounding error), transfer the balance.
        if (amount > rewardBalance) {
            amount = rewardBalance;
        }

        accountedRewards -= amount;

        bool success = REWARD_TOKEN.transfer(to, amount);
        if (!success) {
            revert StakingManager__TransferFailed();
        }
    }

    function getUserInfo(address userAddress) public view returns (UserInfo memory) {
        return users[userAddress];
    }

    /**
     * @dev Sets the rewards per block for a specified duration. This function can only be called by the owner.
     * It mints the necessary reward tokens for the specified duration, considering any unassigned rewards.
     * @param _rewardsPerBlock The new reward rate per block.
     * @param _durationInBlocks The duration for which the new reward rate should be applied.
     */
    function setRewardsPerBlock(uint256 _rewardsPerBlock, uint256 _durationInBlocks) external onlyOwner {
        require(_durationInBlocks > 0, "Duration must be greater than zero");
        updateRewardIndex(); // Ensure rewards are up-to-date before changing the rate

        // Calculate the total rewards needed for the specified duration
        uint256 totalRewardsNeeded = _rewardsPerBlock * _durationInBlocks;

        // Calculate the unassigned rewards currently held by the contract
        uint256 currentBalance = REWARD_TOKEN.balanceOf(address(this));
        uint256 unassignedRewards = currentBalance > accountedRewards ? currentBalance - accountedRewards : 0;

        // Calculate the additional rewards needed
        uint256 additionalRewardsNeeded = 0;
        if (totalRewardsNeeded > unassignedRewards) {
            additionalRewardsNeeded = totalRewardsNeeded - unassignedRewards;
        }

        // Mint the necessary additional reward tokens
        if (additionalRewardsNeeded > 0) {
            REWARD_TOKEN.mint(address(this), additionalRewardsNeeded);
        }

        // Update the rewards per block and reward end block
        rewardsPerBlock = _rewardsPerBlock;
        rewardEndBlock = block.number + _durationInBlocks;
    }
}
