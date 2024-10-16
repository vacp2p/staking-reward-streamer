// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IXPProvider {
    function getTotalXPShares() external view returns (uint256);
    function getUserXPShare(address user) external view returns (uint256);
}
