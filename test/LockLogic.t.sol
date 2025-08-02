// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { StakeVault } from "../src/StakeVault.sol";
import { MockStakeManager } from "./mocks/MockStakeManager.sol";
import { MockToken } from "./mocks/MockToken.sol";

/**
 * @title LockLogicTest
 * @notice Tests to verify the new vault-driven lock logic works correctly
 */
contract LockLogicTest is Test {
    StakeVault internal stakeVault;
    MockStakeManager internal stakeManager;
    MockToken internal stakingToken;
    address internal alice = makeAddr("alice");

    function setUp() public {
        stakingToken = new MockToken("Staking Token", "ST");
        stakeManager = new MockStakeManager();
        
        // Create vault directly (without factory for simplicity)
        stakeVault = new StakeVault(stakingToken);
        stakeVault.initialize(alice, address(stakeManager));
        
        // Mint tokens to alice and approve vault
        stakingToken.mint(alice, 10_000e18);
        vm.prank(alice);
        stakingToken.approve(address(stakeVault), 10_000e18);
    }

    function test_StakeUpdatesLockUntilCorrectly() public {
        // Initial lockUntil should be 0
        assertEq(stakeVault.lockUntil(), 0);
        
        // Stake with 90 days lock
        uint256 lockPeriod = 90 days;
        uint256 stakeTime = block.timestamp;
        
        vm.prank(alice);
        stakeVault.stake(1000e18, lockPeriod);
        
        // Vault should have updated its lockUntil before calling manager
        uint256 expectedLockEnd = stakeTime + lockPeriod; // since initial lockUntil was 0
        assertEq(stakeVault.lockUntil(), expectedLockEnd);
    }

    function test_StakeExtendsExistingLock() public {
        // Set initial lock time in the future
        uint256 initialLockEnd = block.timestamp + 60 days;
        vm.prank(address(stakeManager));
        stakeVault.updateLockUntil(initialLockEnd);
        
        // Stake with additional 90 days
        uint256 additionalLockPeriod = 90 days;
        uint256 stakeTime = block.timestamp;
        
        vm.prank(alice);
        stakeVault.stake(1000e18, additionalLockPeriod);
        
        // Should extend from existing lock, not from current time
        uint256 expectedLockEnd = initialLockEnd + additionalLockPeriod;
        assertEq(stakeVault.lockUntil(), expectedLockEnd);
    }

    function test_StakeExtendsFromCurrentTimeIfLockExpired() public {
        // Set initial lock time in the past
        uint256 pastLockEnd = block.timestamp - 30 days;
        vm.prank(address(stakeManager));
        stakeVault.updateLockUntil(pastLockEnd);
        
        // Stake with 90 days lock
        uint256 lockPeriod = 90 days;
        uint256 stakeTime = block.timestamp;
        
        vm.prank(alice);
        stakeVault.stake(1000e18, lockPeriod);
        
        // Should extend from current time since old lock expired
        uint256 expectedLockEnd = stakeTime + lockPeriod;
        assertEq(stakeVault.lockUntil(), expectedLockEnd);
    }

    function test_LockUpdatesLockUntilCorrectly() public {
        // Initial stake without lock
        vm.prank(alice);
        stakeVault.stake(1000e18, 0);
        
        assertEq(stakeVault.lockUntil(), 0);
        
        // Now lock for 90 days
        uint256 lockPeriod = 90 days;
        uint256 lockTime = block.timestamp;
        
        vm.prank(alice);
        stakeVault.lock(lockPeriod);
        
        uint256 expectedLockEnd = lockTime + lockPeriod;
        assertEq(stakeVault.lockUntil(), expectedLockEnd);
    }

    function test_StakeWithZeroLockDoesNotUpdateLockUntil() public {
        // Stake without lock period
        vm.prank(alice);
        stakeVault.stake(1000e18, 0);
        
        // lockUntil should remain 0  
        assertEq(stakeVault.lockUntil(), 0);
    }
}