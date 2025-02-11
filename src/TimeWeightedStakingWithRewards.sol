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
        uint256 shares; // invariant shares
        uint256 settledRewards;
        uint256 principal;
    }

    mapping(address => Account) public accounts;

    constructor() {
        multiplierStartTime = block.timestamp;
    }

    function currentScalingFactor() public view returns (uint256) {
        uint256 elapsed = block.timestamp - multiplierStartTime;
        return MULTIPLIER + (elapsed * MULTIPLIER / ONE_YEAR);
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Cannot deposit 0");

        Account storage account = accounts[msg.sender];
        uint256 scaling = currentScalingFactor();

        // Mint invariant shares based on the current scaling factor.
        uint256 mintedShares = (amount * MULTIPLIER) / scaling;
        account.shares += mintedShares;
        totalShares += mintedShares;

        // Track the original deposit (principal).
        account.principal += amount;

        // Settle reward accounting for the updated share balance.
        account.settledRewards = (account.shares * accRewardPerShare) / MULTIPLIER;
    }

    function unstake(uint256 amount) external {
        require(amount > 0, "Cannot unstake 0");
        Account storage account = accounts[msg.sender];
        uint256 oldShares = account.shares;
        require(amount <= oldShares, "Insufficient balance");

        // Calculate the new share balance after unstaking.
        uint256 remainingShares = oldShares - amount;

        account.settledRewards = (account.settledRewards * remainingShares) / oldShares;

        // Burn the invariant shares.
        account.shares = remainingShares;
        totalShares -= amount;

        // Update the principal (original staked tokens) for the account.
        require(account.principal >= amount, "Principal underflow");
        account.principal -= amount;

        // In pro transfer `amount` of staked tokens back to the user.
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

    // Returns the effective time-weighted balance.
    function effectiveBalance(address user) public view returns (uint256) {
        Account storage account = accounts[user];
        return (account.shares * currentScalingFactor()) / MULTIPLIER;
    }

    function principalOf(address user) public view returns (uint256) {
        return accounts[user].principal;
    }

    function accountSharesOf(address user) public view returns (uint256) {
        return accounts[user].shares;
    }
}
