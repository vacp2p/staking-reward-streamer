// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IXPProvider } from "./interfaces/IXPProvider.sol";

contract XPToken is Ownable2Step {
    string public constant name = "XP Token";
    string public constant symbol = "XP";
    uint256 public constant decimals = 18;

    uint256 public totalSupply;

    IXPProvider[] public xpProviders;

    error XPToken__TransfersNotAllowed();
    error XPProvider__IndexOutOfBounds();

    constructor(uint256 _totalSupply) Ownable(msg.sender) {
        totalSupply = _totalSupply;
    }

    function setTotalSupply(uint256 _totalSupply) external onlyOwner {
        totalSupply = _totalSupply;
    }

    function addXPProvider(IXPProvider provider) external onlyOwner {
        xpProviders.push(provider);
    }

    function removeXPProvider(uint256 index) external onlyOwner {
        if (index >= xpProviders.length) {
            revert XPProvider__IndexOutOfBounds();
        }

        xpProviders[index] = xpProviders[xpProviders.length - 1];
        xpProviders.pop();
    }

    function getXPProviders() external view returns (IXPProvider[] memory) {
        return xpProviders;
    }

    function balanceOf(address account) public view returns (uint256) {
        uint256 userTotalXPShare = 0;
        uint256 totalXPShares = 0;

        for (uint256 i = 0; i < xpProviders.length; i++) {
            IXPProvider provider = xpProviders[i];
            userTotalXPShare += provider.getUserXPShare(account);
            totalXPShares += provider.getTotalXPShares();
        }

        if (totalXPShares == 0) {
            return 0;
        }

        return (totalSupply * userTotalXPShare) / totalXPShares;
    }

    function transfer(address, uint256) external pure returns (bool) {
        revert XPToken__TransfersNotAllowed();
    }

    function approve(address, uint256) external pure returns (bool) {
        revert XPToken__TransfersNotAllowed();
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        revert XPToken__TransfersNotAllowed();
    }

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }
}
