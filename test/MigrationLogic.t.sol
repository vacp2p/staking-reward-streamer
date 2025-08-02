// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { StakeVault } from "../src/StakeVault.sol";
import { MockStakeManager } from "./mocks/MockStakeManager.sol";
import { MockToken } from "./mocks/MockToken.sol";

/**
 * @title MigrationLogicTest  
 * @notice Tests to verify migration still works with new lock logic
 */
contract MigrationLogicTest is Test {
    StakeVault internal sourceVault;
    StakeVault internal targetVault;
    MockStakeManager internal stakeManager;
    MockToken internal stakingToken;
    address internal alice = makeAddr("alice");

    function setUp() public {
        stakingToken = new MockToken("Staking Token", "ST");
        stakeManager = new MockStakeManager();
        
        // Create two vaults for migration test
        sourceVault = new StakeVault(stakingToken);
        sourceVault.initialize(alice, address(stakeManager));
        
        targetVault = new StakeVault(stakingToken);
        targetVault.initialize(alice, address(stakeManager));
        
        // Mint tokens to alice and approve source vault
        stakingToken.mint(alice, 10_000e18);
        vm.prank(alice);
        stakingToken.approve(address(sourceVault), 10_000e18);
    }

    function test_UpdateLockUntilStillWorksForMigration() public {
        // Set a lock time on the source vault  
        uint256 lockTime = block.timestamp + 90 days;
        vm.prank(address(stakeManager));
        sourceVault.updateLockUntil(lockTime);
        
        assertEq(sourceVault.lockUntil(), lockTime);
        assertEq(targetVault.lockUntil(), 0);
        
        // Migration should be able to transfer lock time to target vault
        vm.prank(address(stakeManager));
        targetVault.updateLockUntil(lockTime);
        
        assertEq(targetVault.lockUntil(), lockTime);
    }

    function test_UpdateLockUntilOnlyWorksFromStakeManager() public {
        uint256 lockTime = block.timestamp + 90 days;
        
        // Should revert when called by non-stake-manager
        vm.prank(alice);
        vm.expectRevert(StakeVault.StakeVault__StakeManagerImplementationNotTrusted.selector);
        sourceVault.updateLockUntil(lockTime);
    }
}