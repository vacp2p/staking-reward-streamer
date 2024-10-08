// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ITrustedCodehashAccess } from "./access/ITrustedCodehashAccess.sol";

interface IStakeManager is ITrustedCodehashAccess {
    error StakeManager__FundsLocked();
    error StakeManager__InvalidLockTime();
    error StakeManager__InsufficientFunds();
    error StakeManager__StakeIsTooLow();

    function stake(uint256 _amount, uint256 _seconds) external;
    function unstake(uint256 _amount) external;
    function lock(uint256 _secondsIncrease) external;
    function leave() external returns (bool _leaveAccepted);
    function acceptUpdate() external returns (address _migrated);

    function potentialMP() external view returns (uint256);
    function totalMP() external view returns (uint256);
    function totalStaked() external view returns (uint256);
    function totalSupply() external view returns (uint256 _totalSupply);
    function totalSupplyMinted() external view returns (uint256 _totalSupply);
    function pendingReward() external view returns (uint256);
    function getStakedBalance(address _vault) external view returns (uint256 _balance);

    function STAKE_TOKEN() external view returns (IERC20);
    function REWARD_TOKEN() external view returns (IERC20);
    function MIN_LOCKUP_PERIOD() external view returns (uint256);
    function MAX_LOCKUP_PERIOD() external view returns (uint256);
    function MP_APY() external view returns (uint256);
    function MAX_BOOST() external view returns (uint256);

    function calculateMP(uint256 _balance, uint256 _deltaTime) public pure returns (uint256);
}
