// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { BaseScript } from "./Base.s.sol";
import { StakeManager } from "../src/StakeManager.sol";
import { IStakeManagerProxy } from "../src/interfaces/IStakeManagerProxy.sol";
import { DeploymentConfig } from "./DeploymentConfig.s.sol";

contract UpgradeStakeManagerScript is BaseScript {
    function run() public returns (address) {
        DeploymentConfig deploymentConfig = new DeploymentConfig(broadcaster);
        (address deployer,, address currentImplProxy) = deploymentConfig.activeNetworkConfig();
        return runWithAdminAndProxy(deployer, IStakeManagerProxy(currentImplProxy));
    }

    function runWithAdminAndProxy(address admin, IStakeManagerProxy currentImplProxy) public returns (address) {
        address deployer = broadcaster;
        if (admin != address(0)) {
            deployer = admin;
        }
        vm.startBroadcast(deployer);
        // Replace this with actual new version of the contract
        address nextImpl = address(new StakeManager());
        UUPSUpgradeable(address(currentImplProxy)).upgradeTo(nextImpl);
        vm.stopBroadcast();
        return nextImpl;
    }
}
