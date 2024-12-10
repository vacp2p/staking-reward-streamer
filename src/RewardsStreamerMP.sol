// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IStakeManager } from "./interfaces/IStakeManager.sol";
import { IStakeVault } from "./interfaces/IStakeVault.sol";
import { TrustedCodehashAccess } from "./TrustedCodehashAccess.sol";

// Rewards Streamer with Multiplier Points
contract RewardsStreamerMP is
    Initializable,
    UUPSUpgradeable,
    IStakeManager,
    TrustedCodehashAccess,
    ReentrancyGuardUpgradeable
{
    error StakingManager__InvalidVault();
    error StakingManager__VaultNotRegistered();
    error StakingManager__VaultAlreadyRegistered();
    error StakingManager__AmountCannotBeZero();
    error StakingManager__TransferFailed();
    error StakingManager__InsufficientBalance();
    error StakingManager__InvalidLockingPeriod();
    error StakingManager__CannotRestakeWithLockedFunds();
    error StakingManager__TokensAreLocked();
    error StakingManager__AlreadyLocked();
    error StakingManager__EmergencyModeEnabled();
    error StakingManager__DurationCannotBeZero();

    IERC20 public STAKING_TOKEN;

    uint256 public constant SCALE_FACTOR = 1e18;
    uint256 public constant MP_RATE_PER_YEAR = 1;

    uint256 public constant YEAR = 365 days;
    uint256 public constant MIN_LOCKUP_PERIOD = 90 days;
    uint256 public constant MAX_LOCKUP_PERIOD = 4 * YEAR;
    uint256 public constant MAX_MULTIPLIER = 4;

    uint256 public totalStaked;
    uint256 public totalMP;
    uint256 public totalMaxMP;
    uint256 public rewardIndex;
    uint256 public lastMPUpdatedTime;
    bool public emergencyModeEnabled;

    uint256 public totalRewardsAccrued;
    uint256 public rewardAmount;
    uint256 public lastRewardTime;
    uint256 public rewardStartTime;
    uint256 public rewardEndTime;

    struct VaultData {
        uint256 stakedBalance;
        uint256 rewardIndex;
        uint256 mp;
        uint256 maxMP;
        uint256 lastMPUpdateTime;
        uint256 lockUntil;
    }

    mapping(address vault => VaultData data) public vaultData;
    mapping(address owner => address[] vault) public vaults;
    mapping(address vault => address owner) public vaultOwners;

    modifier onlyRegisteredVault() {
        if (vaultOwners[msg.sender] == address(0)) {
            revert StakingManager__VaultNotRegistered();
        }
        _;
    }

    modifier onlyNotEmergencyMode() {
        if (emergencyModeEnabled) {
            revert StakingManager__EmergencyModeEnabled();
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner, address _stakingToken) public initializer {
        __TrustedCodehashAccess_init(_owner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        STAKING_TOKEN = IERC20(_stakingToken);
        lastMPUpdatedTime = block.timestamp;
    }

    function _authorizeUpgrade(address) internal view override {
        _checkOwner();
    }

    /**
     * @notice Registers a vault with its owner. Called by the vault itself during initialization.
     * @dev Only callable by contracts with trusted codehash
     */
    function registerVault() external onlyTrustedCodehash {
        address vault = msg.sender;
        address owner = IStakeVault(vault).owner();

        if (vaultOwners[vault] != address(0)) {
            revert StakingManager__VaultAlreadyRegistered();
        }

        // Verify this is a legitimate vault by checking it points to stakeManager
        if (address(IStakeVault(vault).stakeManager()) != address(this)) {
            revert StakingManager__InvalidVault();
        }

        vaultOwners[vault] = owner;
        vaults[owner].push(vault);
    }

    /**
     * @notice Get the vaults owned by a user
     * @param account The address of the user
     * @return The vaults owned by the user
     */
    function getAccountVaults(address account) external view returns (address[] memory) {
        return vaults[account];
    }

    /**
     * @notice Get the total multiplier points for a user
     * @dev Iterates over all vaults owned by the user and sums the multiplier points
     * @param account The address of the user
     * @return The total multiplier points for the user
     */
    function getAccountTotalMP(address account) external view returns (uint256) {
        address[] memory accountVaults = vaults[account];
        uint256 accountTotalMP = 0;

        for (uint256 i = 0; i < accountVaults.length; i++) {
            VaultData storage vault = vaultData[accountVaults[i]];
            accountTotalMP += vault.mp + _getVaultAccruedMP(vault);
        }
        return accountTotalMP;
    }

    /**
     * @notice Get the total maximum multiplier points for a user
     * @dev Iterates over all vaults owned by the user and sums the maximum multiplier points
     * @param account The address of the acocunt
     * @return The total maximum multiplier points for the user
     */
    function getAccountTotalMaxMP(address account) external view returns (uint256) {
        address[] memory accountVaults = vaults[account];
        uint256 accountTotalMaxMP = 0;

        for (uint256 i = 0; i < accountVaults.length; i++) {
            accountTotalMaxMP += vaultData[accountVaults[i]].maxMP;
        }
        return accountTotalMaxMP;
    }

    /**
     * @notice Get the total staked balance for a user
     * @dev Iterates over all vaults owned by the user and sums the staked balances
     * @param account The address of the user
     * @return The total staked balance for the user
     */
    function getAccountTotalStakedBalance(address account) external view returns (uint256) {
        address[] memory accountVaults = vaults[account];
        uint256 accountTotalStake = 0;

        for (uint256 i = 0; i < accountVaults.length; i++) {
            accountTotalStake += vaultData[accountVaults[i]].stakedBalance;
        }
        return accountTotalStake;
    }

    function stake(
        uint256 amount,
        uint256 lockPeriod
    )
        external
        onlyTrustedCodehash
        onlyNotEmergencyMode
        onlyRegisteredVault
        nonReentrant
    {
        if (amount == 0) {
            revert StakingManager__AmountCannotBeZero();
        }

        if (lockPeriod != 0 && (lockPeriod < MIN_LOCKUP_PERIOD || lockPeriod > MAX_LOCKUP_PERIOD)) {
            revert StakingManager__InvalidLockingPeriod();
        }

        _updateGlobalState();
        _updateVaultMP(msg.sender);

        VaultData storage vault = vaultData[msg.sender];
        if (vault.lockUntil != 0 && vault.lockUntil > block.timestamp) {
            revert StakingManager__CannotRestakeWithLockedFunds();
        }

        vault.stakedBalance += amount;
        totalStaked += amount;

        uint256 initialMP = amount;
        uint256 potentialMP = amount * MAX_MULTIPLIER;
        uint256 bonusMP = 0;

        if (lockPeriod != 0) {
            bonusMP = _calculateBonusMP(amount, lockPeriod);
            vault.lockUntil = block.timestamp + lockPeriod;
        } else {
            vault.lockUntil = 0;
        }

        uint256 vaultMaxMP = initialMP + bonusMP + potentialMP;
        uint256 vaultMP = initialMP + bonusMP;

        vault.mp += vaultMP;
        totalMP += vaultMP;

        vault.maxMP += vaultMaxMP;
        totalMaxMP += vaultMaxMP;

        vault.rewardIndex = rewardIndex;
    }

    function lock(uint256 lockPeriod)
        external
        onlyTrustedCodehash
        onlyNotEmergencyMode
        onlyRegisteredVault
        nonReentrant
    {
        if (lockPeriod < MIN_LOCKUP_PERIOD || lockPeriod > MAX_LOCKUP_PERIOD) {
            revert StakingManager__InvalidLockingPeriod();
        }

        VaultData storage vault = vaultData[msg.sender];

        if (vault.lockUntil > 0) {
            revert StakingManager__AlreadyLocked();
        }

        if (vault.stakedBalance == 0) {
            revert StakingManager__InsufficientBalance();
        }

        _updateGlobalState();
        _updateVaultMP(msg.sender);

        uint256 additionalBonusMP = _calculateBonusMP(vault.stakedBalance, lockPeriod);

        // Update vault state
        vault.lockUntil = block.timestamp + lockPeriod;
        vault.mp += additionalBonusMP;
        vault.maxMP += additionalBonusMP;

        // Update global state
        totalMP += additionalBonusMP;
        totalMaxMP += additionalBonusMP;

        vault.rewardIndex = rewardIndex;
    }

    function unstake(uint256 amount)
        external
        onlyTrustedCodehash
        onlyNotEmergencyMode
        onlyRegisteredVault
        nonReentrant
    {
        VaultData storage vault = vaultData[msg.sender];
        if (amount > vault.stakedBalance) {
            revert StakingManager__InsufficientBalance();
        }

        if (block.timestamp < vault.lockUntil) {
            revert StakingManager__TokensAreLocked();
        }
        _unstake(amount, vault, msg.sender);
    }

    function _unstake(uint256 amount, VaultData storage vault, address vaultAddress) internal {
        _updateGlobalState();
        _updateVaultMP(vaultAddress);

        uint256 previousStakedBalance = vault.stakedBalance;

        // solhint-disable-next-line
        uint256 mpToReduce = Math.mulDiv(vault.mp, amount, previousStakedBalance);
        uint256 maxMPToReduce = Math.mulDiv(vault.maxMP, amount, previousStakedBalance);

        vault.stakedBalance -= amount;
        vault.mp -= mpToReduce;
        vault.maxMP -= maxMPToReduce;
        vault.rewardIndex = rewardIndex;
        totalMP -= mpToReduce;
        totalMaxMP -= maxMPToReduce;
        totalStaked -= amount;
    }

    // @notice Allows a vault to leave the system. This can happen when a
    //         user doesn't agree with an upgrade of the stake manager.
    // @dev This function is protected by whitelisting the codehash of the caller.
    //      This ensures `StakeVault`s will call this function only if they don't
    //      trust the `StakeManager` (e.g. in case of an upgrade).
    function leave() external onlyTrustedCodehash nonReentrant {
        VaultData storage vault = vaultData[msg.sender];

        if (vault.stakedBalance > 0) {
            // calling `_unstake` to update accounting accordingly
            _unstake(vault.stakedBalance, vault, msg.sender);

            // further cleanup that isn't done in `_unstake`
            vault.rewardIndex = 0;
            vault.lockUntil = 0;
        }
    }

    function _updateGlobalState() internal {
        updateGlobalMP();
        updateRewardIndex();
    }

    function updateGlobalState() external onlyNotEmergencyMode {
        _updateGlobalState();
    }

    function updateGlobalMP() internal {
        if (totalMaxMP == 0) {
            lastMPUpdatedTime = block.timestamp;
            return;
        }

        uint256 currentTime = block.timestamp;
        uint256 timeDiff = currentTime - lastMPUpdatedTime;
        if (timeDiff == 0) {
            return;
        }

        uint256 accruedMP = (timeDiff * totalStaked * MP_RATE_PER_YEAR) / YEAR;
        if (totalMP + accruedMP > totalMaxMP) {
            accruedMP = totalMaxMP - totalMP;
        }

        // Adjust rewardIndex before updating totalMP
        uint256 previousTotalWeight = totalStaked + totalMP;
        totalMP += accruedMP;

        uint256 newTotalWeight = totalStaked + totalMP;

        if (previousTotalWeight != 0 && newTotalWeight != previousTotalWeight) {
            rewardIndex = (rewardIndex * previousTotalWeight) / newTotalWeight;
        }

        lastMPUpdatedTime = currentTime;
    }

    function setReward(uint256 amount, uint256 duration) external onlyOwner {
        if (duration == 0) {
            revert StakingManager__DurationCannotBeZero();
        }

        if (amount == 0) {
            revert StakingManager__AmountCannotBeZero();
        }

        // this will call _updateRewardIndex and update the totalRewardsAccrued
        _updateGlobalState();

        // in case _updateRewardIndex returns earlier,
        // we still update the lastRewardTime
        lastRewardTime = block.timestamp;
        rewardAmount = amount;
        rewardStartTime = block.timestamp;
        rewardEndTime = block.timestamp + duration;
    }

    function _calculatePendingRewards() internal view returns (uint256) {
        if (rewardEndTime <= rewardStartTime) {
            // No active reward period
            return 0;
        }

        uint256 currentTime = block.timestamp < rewardEndTime ? block.timestamp : rewardEndTime;

        if (currentTime <= lastRewardTime) {
            // No new rewards have accrued since lastRewardTime
            return 0;
        }

        uint256 timeElapsed = currentTime - lastRewardTime;
        uint256 duration = rewardEndTime - rewardStartTime;

        if (duration == 0) {
            // Prevent division by zero
            return 0;
        }

        uint256 accruedRewards = (timeElapsed * rewardAmount) / duration;
        return accruedRewards;
    }

    function updateRewardIndex() internal {
        uint256 totalWeight = totalStaked + totalMP;
        if (totalWeight == 0) {
            return;
        }

        uint256 currentTime = block.timestamp;
        uint256 applicableTime = rewardEndTime > currentTime ? currentTime : rewardEndTime;
        uint256 elapsedTime = applicableTime - lastRewardTime;

        if (elapsedTime == 0) {
            return;
        }

        uint256 newRewards = _calculatePendingRewards();
        if (newRewards == 0) {
            return;
        }

        totalRewardsAccrued += newRewards;
        uint256 indexIncrease = Math.mulDiv(newRewards, SCALE_FACTOR, totalWeight);
        if (indexIncrease > 0) {
            rewardIndex += indexIncrease;
            lastRewardTime = block.timestamp < rewardEndTime ? block.timestamp : rewardEndTime;
        }
    }

    function _calculateBonusMP(uint256 amount, uint256 lockPeriod) internal pure returns (uint256) {
        return Math.mulDiv(amount, lockPeriod, YEAR);
    }

    function _getVaultAccruedMP(VaultData storage vault) internal view returns (uint256) {
        if (vault.maxMP == 0 || vault.stakedBalance == 0) {
            return 0;
        }

        uint256 timeDiff = block.timestamp - vault.lastMPUpdateTime;
        if (timeDiff == 0) {
            return 0;
        }

        uint256 accruedMP = Math.mulDiv(timeDiff * vault.stakedBalance, MP_RATE_PER_YEAR, YEAR);

        if (vault.mp + accruedMP > vault.maxMP) {
            accruedMP = vault.maxMP - vault.mp;
        }
        return accruedMP;
    }

    function _updateVaultMP(address vaultAddress) internal {
        VaultData storage vault = vaultData[vaultAddress];
        uint256 accruedMP = _getVaultAccruedMP(vault);

        vault.mp += accruedMP;
        vault.lastMPUpdateTime = block.timestamp;
    }

    function updateVaultMP(address vaultAddress) external onlyNotEmergencyMode {
        _updateVaultMP(vaultAddress);
    }

    function calculateVaultRewards(address vaultAddress) public view returns (uint256) {
        VaultData storage vault = vaultData[vaultAddress];

        uint256 vaultWeight = vault.stakedBalance + vault.mp;
        uint256 deltaRewardIndex = rewardIndex - vault.rewardIndex;

        return Math.mulDiv(vaultWeight, deltaRewardIndex, SCALE_FACTOR);
    }

    function enableEmergencyMode() external onlyOwner {
        if (emergencyModeEnabled) {
            revert StakingManager__EmergencyModeEnabled();
        }
        emergencyModeEnabled = true;
    }

    function getStakedBalance(address vaultAddress) public view returns (uint256) {
        return vaultData[vaultAddress].stakedBalance;
    }

    function getVaultData(address vaultAddress) external view returns (VaultData memory) {
        return vaultData[vaultAddress];
    }

    function totalRewardsSupply() public view returns (uint256) {
        return totalRewardsAccrued + _calculatePendingRewards();
    }

    function rewardsBalanceOf(address vaultAddress) external view returns (uint256) {
        return calculateVaultRewards(vaultAddress);
    }
}
