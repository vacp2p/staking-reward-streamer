// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { BaseScript } from "./Base.s.sol";
import { DeploymentConfig } from "./DeploymentConfig.s.sol";
import { KarmaWithAccessControl } from "../src/KarmaWithAccessControl.sol";

contract UpgradeToKarmaWithAccessControlScript is BaseScript {
    error ProxyAddressNotSet();

    function run() public returns (address) {
        address currentImplProxy = vm.envAddress("KARMA_PROXY_ADDRESS");
        if (currentImplProxy == address(0)) {
            revert ProxyAddressNotSet();
        }
        DeploymentConfig deploymentConfig = new DeploymentConfig(broadcaster);
        (address deployer,) = deploymentConfig.activeNetworkConfig();
        return runWithAdminAndProxy(deployer, currentImplProxy);
    }

    function runWithAdminAndProxy(address admin, address currentImplProxy) public returns (address) {
        address deployer = broadcaster;
        if (admin != address(0)) {
            deployer = admin;
        }
        vm.startBroadcast(deployer);
        address nextImpl = address(new KarmaWithAccessControl());
        UUPSUpgradeable(address(currentImplProxy)).upgradeTo(nextImpl);
        KarmaWithAccessControl(currentImplProxy).initializeAccessControl();
        vm.stopBroadcast();
        return nextImpl;
    }
}
