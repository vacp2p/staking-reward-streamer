// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { IRewardDistributor } from "./interfaces/IRewardDistributor.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title Karma
 * @notice This contract allows for setting rewards for reward distributors.
 * @dev Implementation of the Karma token
 */
contract Karma is Initializable, ERC20Upgradeable, UUPSUpgradeable, AccessControlUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Emitted when the address is invalid
    error Karma__InvalidAddress();
    /// @notice Emitted because transfers are not allowed
    error Karma__TransfersNotAllowed();
    /// @notice Emitted when distributor is already added
    error Karma__DistributorAlreadyAdded();
    /// @notice Emitted when distributor is not found
    error Karma__UnknownDistributor();
    /// @notice Emitted sender does not have the required role
    error Karma__Unauthorized();
    /// @notice Emitted when slash percentage to set is invalid
    error Karma__InvalidSlashPercentage();
    /// @notice Emitted when the slash cooldown is active
    error Karma__SlashCooldownActive();
    /// @notice Emitted when balance to slash is invalid
    error Karma__CannotSlashZeroBalance();

    event RewardDistributorAdded(address distributor);
    /// @notice Emitted when an account is slashed
    event AccountSlashed(address indexed account, uint256 amount);
    /// @notice Emitted when the slash percentage is updated
    event SlashPercentageUpdated(uint256 oldPercentage, uint256 newPercentage);
    /// @notice Emitted when the slash cooldown is updated
    event SlashCooldownUpdated(uint256 oldCooldown, uint256 newCooldown);

    /*//////////////////////////////////////////////////////////////////////////
                                  CONSTATNS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Maximum slash percentage (in basis points: 100% = 10000)
    uint256 public constant MAX_SLASH_PERCENTAGE = 10_000;
    /// @notice Minimum slash amount
    uint256 public constant MIN_SLASH_AMOUNT = 1 ether;

    /*//////////////////////////////////////////////////////////////////////////
                                  STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice The name of the token
    string public constant NAME = "Karma";
    /// @notice The symbol of the token
    string public constant SYMBOL = "KARMA";
    /// @notice The total allocation for all reward distributors
    uint256 public totalDistributorAllocation;
    /// @notice Set of reward distributors
    EnumerableSet.AddressSet private rewardDistributors;
    /// @notice Mapping of reward distributor to allocation
    mapping(address distributor => uint256 allocation) public rewardDistributorAllocations;
    /// @notice Percentage of Karma to slash (in basis points: 1% = 100, 10% = 1000, 100% = 10000)
    uint256 public slashPercentage;
    /// @notice Slash cooldown in seconds
    uint256 public slashCooldown;
    /// @notice Mapping of slashed accounts to their last slash time
    mapping(address account => uint256 lastSlashTime) public accountLastSlashTime;
    /// @notice Mapping of slashed accounts to their slashed amount
    mapping(address account => uint256 slashedAmount) public accountSlashedAmount;
    /// @notice Operator role keccak256("OPERATOR_ROLE")
    bytes32 public constant OPERATOR_ROLE = 0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929;
    /// @notice Slasher role keccak256("SLASHER_ROLE")
    bytes32 public constant SLASHER_ROLE = 0x12b42e8a160f6064dc959c6f251e3af0750ad213dbecf573b4710d67d6c28e39;

    /// @notice Gap for upgrade safety.
    // solhint-disable-next-line
    uint256[30] private __gap_Karma;

    /// @notice Modifier to check if sender is admin or operator
    modifier onlyAdminOrOperator() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender) && !hasRole(OPERATOR_ROLE, msg.sender)) {
            revert Karma__Unauthorized();
        }
        _;
    }

    /// @notice Modifier to check if sender has slasher role
    modifier onlySlasher() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender) && !hasRole(SLASHER_ROLE, msg.sender)) {
            revert Karma__Unauthorized();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract with the provided owner.
     * @param _owner Address of the owner of the contract.
     */
    function initialize(address _owner) public initializer {
        if (_owner == address(0)) {
            revert Karma__InvalidAddress();
        }
        __ERC20_init(NAME, SYMBOL);
        __UUPSUpgradeable_init();
        __AccessControl_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        slashPercentage = 1000; // 10%
        slashCooldown = 1 days;
    }

    /*//////////////////////////////////////////////////////////////////////////
                           USER-FACING FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a reward distributor to the set of reward distributors.
     * @dev Only the owner can add a reward distributor.
     * @dev Emits a `RewardDistributorAdded` event when a distributor is added.
     * @param distributor The address of the reward distributor.
     */
    function addRewardDistributor(address distributor) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _addRewardDistributor(distributor);
    }

    /**
     * @notice Removes a reward distributor from the set of reward distributors.
     * @dev Only the owner can remove a reward distributor.
     * @param distributor The address of the reward distributor.
     */
    function removeRewardDistributor(address distributor) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _removeRewardDistributor(distributor);
    }

    /**
     * @notice Sets the slash percentage for the contract.
     * @dev Only the admin configure the slash percentage
     * @param percentage The percentage to set (in basis points: 1% = 100, 10% = 1000, 100% = 10000)
     */
    function setSlashPercentage(uint256 percentage) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (percentage > 10_000) {
            revert Karma__InvalidSlashPercentage();
        }
        uint256 oldPercentage = slashPercentage;
        slashPercentage = percentage;
        emit SlashPercentageUpdated(oldPercentage, percentage);
    }

    function setSlashCooldown(uint256 cooldown) public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 oldCooldown = slashCooldown;
        slashCooldown = cooldown;
        emit SlashCooldownUpdated(oldCooldown, cooldown);
    }
    /**
     * @notice Sets the reward for a reward distributor.
     * @dev Only the owner can set the reward for a reward distributor.
     * @dev The total allocation for all reward distributors is updated.
     * @param rewardsDistributor The address of the reward distributor.
     * @param amount The amount of rewards to set.
     * @param duration The duration of the rewards.
     */

    function setReward(
        address rewardsDistributor,
        uint256 amount,
        uint256 duration
    )
        public
        virtual
        onlyAdminOrOperator
    {
        _setReward(rewardsDistributor, amount, duration);
    }

    /**
     * @notice Mints tokens to an account.
     * @dev Only the owner can mint tokens.
     * @dev The amount minted must not exceed the mint allowance.
     * @param account The account to mint tokens to.
     * @param amount The amount of tokens to mint.
     */
    function mint(address account, uint256 amount) public virtual onlyAdminOrOperator {
        _overflowCheck(amount);
        _mint(account, amount);
    }

    /**
     * @notice Slashes karma from an account based on the current slashing percentage
     * @dev Only accounts with the SLASHER_ROLE can call this function
     * @param account Account to slash
     * @return slashedAmount The amount of karma that was slashed
     */
    function slash(address account) public virtual onlySlasher returns (uint256) {
        return _slash(account);
    }

    /**
     * @notice Calculates the amount to slash from an account based on the current slashing percentage
     * @param account Account to slash
     * @return slashedAmount The amount of karma that would be slashed
     */
    function calculateSlashAmount(address account) public view returns (uint256) {
        return _calculateSlashAmount(account);
    }

    function transfer(address, uint256) public pure override returns (bool) {
        revert Karma__TransfersNotAllowed();
    }

    function approve(address, uint256) public pure override returns (bool) {
        revert Karma__TransfersNotAllowed();
    }

    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert Karma__TransfersNotAllowed();
    }

    /*//////////////////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function _totalSupply() internal view returns (uint256) {
        return super.totalSupply() + _externalSupply();
    }

    /**
     * @notice Returns the external supply of the token.
     * @dev The external supply is the sum of the rewards from all reward distributors.
     * @return The external supply of the token.
     */
    function _externalSupply() internal view returns (uint256) {
        uint256 externalSupply;

        for (uint256 i = 0; i < rewardDistributors.length(); i++) {
            IRewardDistributor distributor = IRewardDistributor(rewardDistributors.at(i));
            uint256 supply = distributor.totalRewardsSupply();
            externalSupply += supply;
        }

        if (externalSupply > totalDistributorAllocation) {
            return totalDistributorAllocation;
        }

        return externalSupply;
    }

    /**
     * @notice Authorizes contract upgrades via UUPS.
     * @dev This function is only callable by the owner.
     */
    function _authorizeUpgrade(address) internal view override {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert Karma__Unauthorized();
        }
    }

    /**
     * @notice Adds a reward distributor to the set of reward distributors.
     * @param distributor The address of the reward distributor.
     */
    function _addRewardDistributor(address distributor) internal virtual {
        if (rewardDistributors.contains(distributor)) {
            revert Karma__DistributorAlreadyAdded();
        }

        rewardDistributors.add(distributor);
        emit RewardDistributorAdded(distributor);
    }

    /**
     * @notice Removes a reward distributor from the set of reward distributors.
     * @param distributor The address of the reward distributor.
     */
    function _removeRewardDistributor(address distributor) internal virtual {
        if (!rewardDistributors.contains(distributor)) {
            revert Karma__UnknownDistributor();
        }
        rewardDistributors.remove(distributor);
    }

    /**
     * @notice Sets the reward for a reward distributor.
     */
    function _setReward(address rewardsDistributor, uint256 amount, uint256 duration) internal virtual {
        if (!rewardDistributors.contains(rewardsDistributor)) {
            revert Karma__UnknownDistributor();
        }
        _overflowCheck(amount);

        rewardDistributorAllocations[rewardsDistributor] += amount;
        totalDistributorAllocation += amount;
        IRewardDistributor(rewardsDistributor).setReward(amount, duration);
    }

    /**
     * @notice Slashes karma from an account based on the current slashing percentage
     * @param account Account to slash
     * @return slashedAmount The amount of karma that was slashed
     */
    function _slash(address account) internal virtual returns (uint256) {
        if (block.timestamp < accountLastSlashTime[account] + slashCooldown) {
            revert Karma__SlashCooldownActive();
        }

        uint256 currentBalance = balanceOf(account);
        if (currentBalance == 0) {
            revert Karma__CannotSlashZeroBalance();
        }

        uint256 amountToSlash = _calculateSlashAmount(account);
        accountSlashedAmount[account] += amountToSlash;
        accountLastSlashTime[account] = block.timestamp;

        emit AccountSlashed(account, amountToSlash);

        return amountToSlash;
    }

    /**
     * @notice Calculates the amount to slash from an account based on the current slashing percentage
     */
    function _calculateSlashAmount(address account) internal view returns (uint256) {
        uint256 currentBalance = balanceOf(account);
        uint256 amountToSlash = Math.mulDiv(currentBalance, slashPercentage, MAX_SLASH_PERCENTAGE);
        if (amountToSlash < MIN_SLASH_AMOUNT) {
            if (currentBalance < MIN_SLASH_AMOUNT) {
                // Not enough balance for minimum slash, slash entire balance
                amountToSlash = currentBalance;
            } else {
                amountToSlash = MIN_SLASH_AMOUNT;
            }
        }
        return amountToSlash;
    }

    /**
     * @notice Returns the raw balance of an account.
     */
    function _rawBalanceOf(address account) internal view returns (uint256) {
        uint256 externalBalance;

        for (uint256 i = 0; i < rewardDistributors.length(); i++) {
            address distributor = rewardDistributors.at(i);
            externalBalance += IRewardDistributor(distributor).rewardsBalanceOfAccount(account);
        }

        return super.balanceOf(account) + externalBalance;
    }

    function _overflowCheck(uint256 amount) internal view {
        // This will revert if `amount` overflows the total supply
        super.totalSupply() + totalDistributorAllocation + amount;
    }

    /*//////////////////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the total supply of the token.
     * @dev The total supply is the sum of the token supply and the external supply.
     * @return The total supply of the token.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply();
    }

    /**
     * @notice Returns the reward distributors.
     * @return The reward distributors.
     */
    function getRewardDistributors() external view returns (address[] memory) {
        return rewardDistributors.values();
    }

    /**
     * @notice Returns the balance of an account.
     * @dev The balance of an account is the sum of the balance of the account and the external rewards
     * @param account The account to get the balance of.
     * @return The balance of the account.
     */
    function balanceOf(address account) public view override returns (uint256) {
        uint256 rawBalance = _rawBalanceOf(account);
        // Subtract slashed amount
        if (accountSlashedAmount[account] >= rawBalance) {
            return 0;
        }
        return rawBalance - accountSlashedAmount[account];
    }

    function allowance(address, address) public pure override returns (uint256) {
        return 0;
    }

    /**
     * @notice Returns the external supply of the token.
     * @dev The external supply is the sum of the rewards from all reward distributors.
     * @return The external supply of the token.
     */
    function externalSupply() public view returns (uint256) {
        return _externalSupply();
    }
}
