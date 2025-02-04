// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console } from "forge-std/console.sol";

contract StakingContract {
    uint256 public constant SCALE_FACTOR = 1e18;

    uint256 public totalStaked;
    uint256 public totalMP;
    uint256 public lastMPUpdate;
    uint256 public rewardIndex;
    uint256 public rewardBalance;
    uint256 public accountedRewards;

    struct UserInfo {
        uint256 stakedBalance;
        uint256 userRewardIndex;
        uint256 claimedRewards;
        uint256 mp;
        uint256 lastMPUpdate;
    }

    mapping(address account => UserInfo data) public users;

    constructor() { }

    function addReward(uint256 amount) external {
        rewardBalance += amount;
    }

    function stake(uint256 amount) external {
        updateGlobalState();

        UserInfo storage user = users[msg.sender];
        uint256 userRewards = calculateUserRewards(msg.sender);
        if (userRewards > 0) {
            distributeRewards(msg.sender, userRewards);
        }

        // update user's MP before adding the new stakedBalance
        // if it's the first time staking, the user's MP will be 0
        user.mp = currentUserMP(msg.sender);
        user.stakedBalance += amount;
        user.mp += amount;
        user.lastMPUpdate = block.timestamp;
        totalStaked += amount;
        user.userRewardIndex = rewardIndex;

        totalMP += amount;
        lastMPUpdate = block.timestamp;
    }

    function currentTotalMP() public view returns (uint256) {
        uint256 timePassed = block.timestamp - lastMPUpdate;
        return totalMP + (totalStaked * timePassed) / 31_536_000; // 1 year in seconds
    }

    function updateGlobalState() public {
        updateRewardIndex();
        updateGlobalMP();
    }

    // update global MP with 100% APY
    function updateGlobalMP() public {
        totalMP = currentTotalMP();
        lastMPUpdate = block.timestamp;
    }

    function claimRewards(address userAddress) external {
        uint256 userRewards = calculateUserRewards(userAddress);
        if (userRewards > 0) {
            distributeRewards(userAddress, userRewards);
        }

        UserInfo storage user = users[userAddress];
        uint256 timePassed = block.timestamp - user.lastMPUpdate;
        uint256 newMP = (user.stakedBalance * timePassed) / 31_536_000; // 1 year in seconds
        user.mp += newMP;
        user.lastMPUpdate = block.timestamp;
    }

    function updateRewardIndex() public {
        if (currentTotalMP() == 0) {
            return;
        }

        uint256 newRewards = rewardBalance > accountedRewards ? rewardBalance - accountedRewards : 0;
        if (newRewards > 0) {
            rewardIndex += (newRewards * SCALE_FACTOR) / currentTotalMP();
            accountedRewards += newRewards;
        }
    }

    function getStakedBalance(address userAddress) public view returns (uint256) {
        return users[userAddress].stakedBalance;
    }

    function getPendingRewards(address userAddress) public view returns (uint256) {
        return calculateUserRewards(userAddress);
    }

    function calculateUserRewards(address userAddress) public view returns (uint256) {
        UserInfo storage user = users[userAddress];
        return (currentUserMP(userAddress) * (rewardIndex - user.userRewardIndex)) / SCALE_FACTOR;
    }

    function currentUserMP(address userAddress) public view returns (uint256) {
        UserInfo storage user = users[userAddress];
        uint256 timePassed = block.timestamp - user.lastMPUpdate;
        // Return the stored MP plus the additional accrued MP since the last update.
        return user.mp + (user.stakedBalance * timePassed) / 31_536_000;
    }

    function distributeRewards(address to, uint256 amount) internal {
        // If amount is higher than the contract's balance (for rounding error), transfer the balance.
        if (amount > rewardBalance) {
            amount = rewardBalance;
        }

        accountedRewards -= amount;
        rewardBalance -= amount;

        UserInfo storage user = users[to];
        user.userRewardIndex = rewardIndex;
        user.claimedRewards += amount;
    }

    function accountRewardIndex(address userAddress) public view returns (uint256) {
        UserInfo storage user = users[userAddress];
        return user.userRewardIndex;
    }

    function accountClaimedRewards(address userAddress) public view returns (uint256) {
        UserInfo storage user = users[userAddress];
        return user.claimedRewards;
    }

    function accountMP(address userAddress) public view returns (uint256) {
        UserInfo storage user = users[userAddress];
        return user.mp;
    }

    function accountStakedBalance(address userAddress) public view returns (uint256) {
        UserInfo storage user = users[userAddress];
        return user.stakedBalance;
    }

    function getUserInfo(address userAddress) public view returns (UserInfo memory) {
        return users[userAddress];
    }
}
