// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { BaseScript } from "./Base.s.sol";
import { DeploymentConfig } from "./DeploymentConfig.s.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { Groth16Verifier } from "../src/rln/Verifier.sol";
import { KarmaRLN } from "../src/rln/KarmaRLN.sol";

contract DeployKarmaScript is BaseScript {
    function run() public returns (KarmaRLN, DeploymentConfig) {
        DeploymentConfig deploymentConfig = new DeploymentConfig(broadcaster);
        (address deployer,) = deploymentConfig.activeNetworkConfig();

        uint256 depth = vm.envUint("DEPTH");
        address karmaAddress = vm.envAddress("KARMA_ADDRESS");

        vm.startBroadcast(deployer);
        address verifier = (address)(new Groth16Verifier());
        // Deploy Karma logic contract
        bytes memory initializeData =
            abi.encodeCall(KarmaRLN.initialize, (deployer, deployer, deployer, depth, verifier, karmaAddress));
        address impl = address(new KarmaRLN());
        // Create upgradeable proxy
        address proxy = address(new ERC1967Proxy(impl, initializeData));

        vm.stopBroadcast();

        return (KarmaRLN(proxy), deploymentConfig);
    }
}
