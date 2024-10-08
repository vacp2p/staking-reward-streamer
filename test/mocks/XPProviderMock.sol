// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IXPProvider } from "../../src/interfaces/IXPProvider.sol";

contract XPProviderMock is IXPProvider {
    mapping(address => uint256) public userXPContribution;

    uint256 public totalXPContribution;

    function setUserXPContribution(address user, uint256 xp) external {
        userXPContribution[user] = xp;
    }

    function setTotalXPContribution(uint256 xp) external {
        totalXPContribution = xp;
    }

    function getUserXPContribution(address account) external view override returns (uint256) {
        return userXPContribution[account];
    }

    function getTotalXPContribution() external view override returns (uint256) {
        return totalXPContribution;
    }
}
