// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console } from "forge-std/console.sol";

contract TimeWeightedStakingWithRewards {
    uint256 public constant MULTIPLIER = 1e18;
    uint256 public constant ONE_YEAR = 365 days;

    uint256 public multiplierStartTime;
    uint256 public totalShares;

    uint256 public accRewardPerShare;

    struct Account {
        uint256 shares;
        uint256 settledRewards;
    }

    mapping(address => Account) public accounts;

    constructor() {
        multiplierStartTime = block.timestamp;
    }

    function currentScalingFactor() public view returns (uint256) {
        uint256 elapsed = block.timestamp - multiplierStartTime;
        return MULTIPLIER + (elapsed * MULTIPLIER / ONE_YEAR);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Cannot deposit 0");

        Account storage account = accounts[msg.sender];

        uint256 scaling = currentScalingFactor();

        // shares proportional to the deposit and inversely proportional to scaling.
        uint256 mintedShares = (amount * MULTIPLIER) / scaling;
        account.shares += mintedShares;
        totalShares += mintedShares;

        account.settledRewards = (account.shares * accRewardPerShare) / MULTIPLIER;
    }

    function unstake(uint256 originalAmount) external {
        require(originalAmount > 0, "Cannot unstake 0");
        Account storage account = accounts[msg.sender];
        require(originalAmount <= account.shares, "Insufficient balance");

        uint256 currentRewardDebt = (account.shares * accRewardPerShare) / MULTIPLIER;

        if (account.settledRewards < currentRewardDebt) {
            account.settledRewards = currentRewardDebt;
        }

        uint256 rewardDebtReduction = (originalAmount * accRewardPerShare) / MULTIPLIER;
        require(account.settledRewards >= rewardDebtReduction, "Reward accounting underflow");
        account.settledRewards -= rewardDebtReduction;

        // burn shares
        account.shares -= originalAmount;
        totalShares -= originalAmount;

        uint256 payout = originalAmount;
        // send back the original staked tokens
    }

    function addRewards(uint256 rewardAmount) external {
        require(totalShares > 0, "No stakes");
        uint256 delta = (rewardAmount * MULTIPLIER) / totalShares;
        accRewardPerShare += delta;
    }

    function rewardsBalanceOf(address user) public view returns (uint256 pending) {
        Account storage account = accounts[user];
        pending = (account.shares * accRewardPerShare) / MULTIPLIER - account.settledRewards;
    }

    function effectiveBalance(address user) public view returns (uint256) {
        Account storage account = accounts[user];
        return (account.shares * currentScalingFactor()) / MULTIPLIER;
    }
}
