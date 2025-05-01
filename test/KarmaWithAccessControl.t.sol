// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { Karma } from "../src/Karma.sol";
import { KarmaWithAccessControl } from "../src/KarmaWithAccessControl.sol";
import { DeploymentConfig } from "../script/DeploymentConfig.s.sol";
import { DeployKarmaScript } from "../script/DeployKarma.s.sol";
import { UpgradeToKarmaWithAccessControlScript } from "../script/UpgradeToKarmaWithAccessControl.s.sol";
import { KarmaDistributorMock } from "./mocks/KarmaDistributorMock.sol";

contract KarmaWithAccessControlTest is Test {
    KarmaWithAccessControl public karma;

    address public deployer;

    address public operator = makeAddr("operator");

    address public distributor;

    function setUp() public virtual {
        // Deploy the original Karma contract
        DeployKarmaScript karmaDeployment = new DeployKarmaScript();
        (Karma _karma, DeploymentConfig config) = karmaDeployment.run();
        (deployer,) = config.activeNetworkConfig();

        // upgrade to KarmaWithAccessControl
        UpgradeToKarmaWithAccessControlScript upgrade = new UpgradeToKarmaWithAccessControlScript();
        upgrade.runWithAdminAndProxy(deployer, address(_karma));
        karma = KarmaWithAccessControl(address(_karma));

        distributor = address(new KarmaDistributorMock());
    }

    function test_InitializeAccessControl() public {
        assert(karma.hasRole(karma.DEFAULT_ADMIN_ROLE(), deployer));
    }
}

contract AddRewardDistributorTest is KarmaWithAccessControlTest {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_RevertWhen_SenderIsNotDefaultAdmin() public {
        vm.prank(makeAddr("someone"));
        vm.expectRevert();
        karma.addRewardDistributor(distributor);
    }

    function testAddRewardDistributor() public {
        vm.prank(deployer);
        karma.addRewardDistributor(distributor);
        address[] memory distributors = karma.getRewardDistributors();
        assertEq(distributors.length, 1);
        assertEq(distributors[0], distributor);
    }

    function testAddRewardDistributorAsOtherAdmin() public {
        address otherAdmin = makeAddr("otherAdmin");
        vm.startPrank(deployer);
        karma.grantRole(karma.DEFAULT_ADMIN_ROLE(), otherAdmin);
        vm.stopPrank();

        vm.prank(otherAdmin);
        karma.addRewardDistributor(distributor);
        address[] memory distributors = karma.getRewardDistributors();
        assertEq(distributors.length, 1);
        assertEq(distributors[0], distributor);
    }
}

contract RemoveRewardDistributorTest is KarmaWithAccessControlTest {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_RevertWhen_SenderIsNotDefaultAdmin() public {
        vm.expectRevert();
        karma.removeRewardDistributor(distributor);
    }

    function testRemoveRewardDistributor() public {
        // add a distributor
        vm.prank(deployer);
        karma.addRewardDistributor(distributor);
        address[] memory distributors = karma.getRewardDistributors();
        assertEq(distributors.length, 1);
        assertEq(distributors[0], distributor);

        // remove the distributor
        vm.prank(deployer);
        karma.removeRewardDistributor(distributor);
        distributors = karma.getRewardDistributors();
        assertEq(distributors.length, 0);
    }

    function testRemoveRewardDistributorAsOtherAdmin() public {
        // add a distributor
        vm.prank(deployer);
        karma.addRewardDistributor(distributor);
        address[] memory distributors = karma.getRewardDistributors();
        assertEq(distributors.length, 1);
        assertEq(distributors[0], distributor);

        // grant admin role
        address otherAdmin = makeAddr("otherAdmin");
        vm.startPrank(deployer);
        karma.grantRole(karma.DEFAULT_ADMIN_ROLE(), otherAdmin);
        vm.stopPrank();

        // remove the distributor
        vm.prank(otherAdmin);
        karma.removeRewardDistributor(distributor);
        distributors = karma.getRewardDistributors();
        assertEq(distributors.length, 0);
    }
}

contract SetRewardTest is KarmaWithAccessControlTest {
    function setUp() public virtual override {
        super.setUp();
        vm.prank(deployer);
        karma.addRewardDistributor(distributor);
    }

    function test_RevertWhen_SenderIsNotDefaultAdmin() public {
        vm.prank(makeAddr("someone"));
        vm.expectRevert();
        karma.setReward(distributor, 0, 0);
    }

    function test_RevertWhen_SenderIsNotOperator() public {
        assert(karma.hasRole(karma.OPERATOR_ROLE(), operator) == false);

        vm.prank(operator);
        vm.expectRevert();
        karma.setReward(distributor, 0, 0);
    }

    function testSetRewardAsAdmin() public {
        vm.prank(deployer);
        karma.setReward(distributor, 0, 0);
    }

    function testSetRewardAsOtherAdmin() public {
        vm.startPrank(deployer);
        karma.grantRole(karma.DEFAULT_ADMIN_ROLE(), operator);
        vm.stopPrank();

        vm.prank(operator);
        karma.setReward(distributor, 0, 0);
    }

    function testSetRewardAsOperator() public {
        // grant operator role
        assert(karma.hasRole(karma.DEFAULT_ADMIN_ROLE(), deployer));

        // actually `vm.prank()` should be used here, but for some reason
        // foundry seems to mess up the context for what `deployer` is
        vm.startPrank(deployer);
        karma.grantRole(karma.OPERATOR_ROLE(), operator);
        vm.stopPrank();

        // set reward as operator
        vm.prank(operator);
        karma.setReward(distributor, 0, 0);
    }
}
