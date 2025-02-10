// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/TimeWeightedStakingWithRewards.sol";
import "forge-std/console.sol";

contract TimeWeightedStakingSimpleClaims is Test {
    TimeWeightedStakingWithRewards staking;
    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        staking = new TimeWeightedStakingWithRewards();
    }

    function dump() public view {
        console.log("--------------------");
        console.log("Alice:");
        // console.log("  Shares:      ", staking.sharesOf(alice));
        console.log("  Rewards:     ", staking.rewardsBalanceOf(alice));
        console.log("Bob:");
        // console.log("  Shares:      ", staking.sharesOf(bob));
        console.log("  Rewards:     ", staking.rewardsBalanceOf(bob));
        console.log("Total:");
        console.log("  All Shares:  ", staking.totalShares());
        console.log("  All Rewards: ", staking.rewardsBalanceOf(alice) + staking.rewardsBalanceOf(bob));
        console.log("--------------------");
    }

    function testTimeWeightedRewards() public {
        // Capture the start time from the contract.
        uint256 start = staking.multiplierStartTime();

        console.log("Day 0: Alice stakes 100");
        vm.prank(alice);
        staking.stake(100e18);
        dump();

        console.log("Half Year Passed - No Rewards Yet");
        vm.warp(start + 182 days);
        dump();

        console.log("End of Year 1: Add 1000 rewards");
        vm.warp(start + 365 days);
        staking.addRewards(1000e18);
        dump();

        console.log("Start of Year 2: Bob stakes 100");
        vm.prank(bob);
        staking.stake(100e18);
        dump();

        console.log("End of Year 2: Add 1000 rewards");
        vm.warp(start + 730 days);
        staking.addRewards(1000e18);
        dump();

        console.log("Claiming rewards after 2 years");
        uint256 aliceRewards = staking.rewardsBalanceOf(alice);
        uint256 bobRewards = staking.rewardsBalanceOf(bob);

        console.log("Alice claims", aliceRewards);
        console.log("Bob claims", bobRewards);
        dump();
    }
}
