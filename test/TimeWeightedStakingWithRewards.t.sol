// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/TimeWeightedStakingWithRewards.sol";

contract TimeWeightedStakingWithRewardsTest is Test {
    TimeWeightedStakingWithRewards staking;
    address alice = address(0x1);
    address bob = address(0x2);
    address charlie = address(0x3);

    function setUp() public {
        staking = new TimeWeightedStakingWithRewards();
    }

    function testTimeWeightedRewards() public {
        // Capture the start time from the contract.
        uint256 start = staking.multiplierStartTime();

        console.log("day 0");
        console.log("alice stakes 100");
        vm.prank(alice);
        staking.stake(100e18);
        dump();

        console.log("1 year");
        console.log("add 1000 rewards");
        vm.warp(start + 365 days);
        staking.addRewards(1000e18);

        console.log("bob stakes 100");
        vm.prank(bob);
        staking.stake(100e18);
        dump();

        console.log("2 years");
        console.log("add 1000 rewards");
        vm.warp(start + 730 days);
        staking.addRewards(1000e18);

        console.log("charlie stakes 100");
        vm.prank(charlie);
        staking.stake(100e18);

        dump();

        console.log("3 years no rewards");
        vm.warp(start + 730 days);
        dump();

        console.log("4 years");
        console.log("add 1000 rewards");
        vm.warp(start + 1460 days);
        staking.addRewards(1000e18);
        dump();

        console.log("10 years no rewards");
        vm.warp(start + 3650 days);
        dump();

        console.log("100 years");
        console.log("add 1000 rewards");
        staking.addRewards(1000e18);
        vm.warp(start + 36_500 days);
        dump();

        // staking.addRewards(1000e18);
    }

    function dump() public view {
        console.log("--------------------");
        console.log("alice principle", staking.principalOf(alice));
        console.log("alice shares   ", staking.accountSharesOf(alice));
        console.log("alice effective", staking.effectiveBalance(alice));
        console.log("bob   principle", staking.principalOf(bob));
        console.log("bob   shares   ", staking.accountSharesOf(bob));
        console.log("bob   effective", staking.effectiveBalance(bob));
        console.log("charlie principle", staking.principalOf(charlie));
        console.log("charlie shares   ", staking.accountSharesOf(charlie));
        console.log("charlie effective", staking.effectiveBalance(charlie));
        console.log("alice          ", staking.rewardsBalanceOf(alice));
        console.log("bob            ", staking.rewardsBalanceOf(bob));
        console.log("charlie        ", staking.rewardsBalanceOf(charlie));
        console.log(
            "total   ",
            staking.rewardsBalanceOf(alice) + staking.rewardsBalanceOf(bob) + staking.rewardsBalanceOf(charlie)
        );
        console.log("--------------------");
    }

    function testTimeWeightedRewardsUnstake() public {
        // Capture the start time from the contract.
        uint256 start = staking.multiplierStartTime();

        console.log("day 0");
        console.log("alice stakes 100");
        vm.prank(alice);
        staking.stake(100e18);
        dump();

        console.log("1 year");
        // console.log("add 1000 rewards");
        vm.warp(start + 365 days);
        // staking.addRewards(1000e18);

        console.log("bob stakes 100");
        vm.prank(bob);
        staking.stake(100e18);

        dump();

        console.log("2 years");
        console.log("add 1000 rewards");
        vm.warp(start + 730 days);
        staking.addRewards(1000e18);

        dump();

        console.log("3 years alice");
        console.log("3 years alice unstakes 100");
        vm.warp(start + 730 days);
        vm.prank(alice);
        staking.unstake(50e18);

        dump();

        console.log("add 1000 rewards");
        staking.addRewards(1000e18);
        dump();

        console.log("10 years no rewards");
        console.log("charlie stakes 100");
        vm.warp(start + 3650 days);
        vm.prank(charlie);
        staking.stake(100e18);
        dump();

        console.log("11 years");
        vm.warp(start + 4015 days);
        dump();
    }
}
