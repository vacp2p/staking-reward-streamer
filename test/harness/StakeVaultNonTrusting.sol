// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IStakeManager } from "../../src/interfaces/IStakeManager.sol";
import { StakeVault } from "../../src/StakeVault.sol";

contract StakeVaultNonTrusting is StakeVault {
    constructor(address _owner, IStakeManager _stakeManager) StakeVault(_owner, _stakeManager) { }

    function _stakeManagerImplementationTrusted() internal pure override returns (bool) {
        return false;
    }

    function stakeNonTrusted(uint256 _amount, uint256 _time) public {
        _stake(_amount, _time, msg.sender);
    }
}
