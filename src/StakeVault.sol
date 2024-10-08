// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/IERC20/IERC20.sol";
import { IStakeManager } from "./IStakeManager.sol";

/**
 * @title StakeVault
 * @author Ricardo Guilherme Schmidt <ricardo3@status.im>
 * @notice A contract to secure user stakes and manage staking with IStakeManager.
 * @dev This contract is owned by the user and allows staking, unstaking, and withdrawing tokens.
 */
contract StakeVault is Ownable {
    error StakeVault__NoEnoughAvailableBalance();
    error StakeVault__InvalidDestinationAddress();
    error StakeVault__UpdateNotAvailable();
    error StakeVault__StakingFailed();
    error StakeVault__UnstakingFailed();

    //STAKE_TOKEN must be kept as an immutable, otherwise, IStakeManager would accept StakeVaults with any token
    //if is needed that STAKE_TOKEN to be a variable, IStakeManager should be changed to check codehash and
    //StakeVault(msg.sender).STAKE_TOKEN()
    IERC20 public immutable STAKE_TOKEN;
    IStakeManager private stakeManager;

    /**
     * @dev Emitted when tokens are staked.
     * @param from The address from which tokens are transferred.
     * @param to The address receiving the staked tokens (this contract).
     * @param amount The amount of tokens staked.
     * @param time The time period for which tokens are staked.
     */
    event Staked(address indexed from, address indexed to, uint256 amount, uint256 time);

    modifier validDestination(address _destination) {
        if (_destination == address(0)) {
            revert StakeVault__InvalidDestinationAddress();
        }
        _;
    }

    /**
     * @notice Initializes the contract with the owner, staked token, and stake manager.
     * @param _owner The address of the owner.
     * @param _stakedToken The IERC20 token to be staked.
     * @param _stakeManager The address of the IStakeManager contract.
     */
    constructor(address _owner, IStakeManager _stakeManager) {
        _transferOwnership(_owner);
        STAKE_TOKEN = _stakeManager.STAKE_TOKEN();
        stakeManager = _stakeManager;
    }

    /**
     * @notice Stake tokens for a specified time.
     * @param _amount The amount of tokens to stake.
     * @param _seconds The time period to stake for.
     */
    function stake(uint256 _amount, uint256 _seconds) external onlyOwner {
        _stake(_amount, _seconds, msg.sender);
    }

    /**
     * @notice Stake tokens from a specified address for a specified time.
     * @param _amount The amount of tokens to stake.
     * @param _seconds The time period to stake for.
     * @param _from The address from which tokens will be transferred.
     */
    function stake(uint256 _amount, uint256 _seconds, address _from) external onlyOwner {
        _stake(_amount, _seconds, _from);
    }

    /**
     * @notice Extends the lock time of the stake.
     * @param _secondsIncrease The additional time to lock the stake.
     */
    function lock(uint256 _secondsIncrease) external onlyOwner {
        stakeManager.lock(_secondsIncrease);
    }

    /**
     * @notice Unstake a specified amount of tokens and send to the owner.
     * @param _amount The amount of tokens to unstake.
     */
    function unstake(uint256 _amount) external onlyOwner {
        _unstake(_amount, msg.sender);
    }

    /**
     * @notice Unstake a specified amount of tokens and send to a destination address.
     * @param _amount The amount of tokens to unstake.
     * @param _destination The address to receive the unstaked tokens.
     */
    function unstake(uint256 _amount, address _destination) external onlyOwner validDestination(_destination) {
        _unstake(_amount, _destination);
    }

    /**
     * @notice Withdraw tokens from the contract.
     * @param _token The IERC20 token to withdraw.
     * @param _amount The amount of tokens to withdraw.
     */
    function withdraw(IERC20 _token, uint256 _amount) external onlyOwner {
        _withdraw(_token, _amount, msg.sender);
    }

    /**
     * @notice Withdraw tokens from the contract to a destination address.
     * @param _token The IERC20 token to withdraw.
     * @param _amount The amount of tokens to withdraw.
     * @param _destination The address to receive the tokens.
     */
    function withdraw(
        IERC20 _token,
        uint256 _amount,
        address _destination
    )
        external
        onlyOwner
        validDestination(_destination)
    {
        _withdraw(_token, _amount, _destination);
    }

    /**
     * @notice Withdraw Ether from the contract to the owner address.
     * @param _amount The amount of Ether to withdraw.
     */
    function withdraw(uint256 _amount) external onlyOwner {
        _withdraw(_amount, payable(msg.sender));
    }

    /**
     * @notice Withdraw Ether from the contract to a destination address.
     * @param _amount The amount of Ether to withdraw.
     * @param _destination The address to receive the Ether.
     */
    function withdraw(
        uint256 _amount,
        address payable _destination
    )
        external
        onlyOwner
        validDestination(_destination)
    {
        _withdraw(_amount, _destination);
    }

    /**
     * @notice Leave staking contract and withdraw all tokens to the owner, in case StakeManager have breached contract.
     */
    function exit() external onlyOwner {
        _exit(msg.sender);
    }

    /**
     * @notice Reject update, exit staking contract and withdraw all tokens to a destination address.
     * @param _destination The address to receive the tokens.
     */
    function exit(address _destination) external onlyOwner validDestination(_destination) {
        _exit(_destination);
    }

    /**
     * @notice Opt-in update to a new IStakeManager contract.
     * @dev Updates the stakeManager to the migrated contract.
     */
    function acceptUpdate() external onlyOwner {
        IStakeManager migrated = stakeManager.acceptUpdate();
        if (address(migrated) == address(0)) revert StakeVault__UpdateNotAvailable();
        stakeManager = migrated;
    }

    /**
     * @notice Returns the available amount of a token that can be withdrawn.
     * @param _token The IERC20 token to check.
     * @return The amount of token available for withdrawal.
     */
    function availableWithdraw(IERC20 _token) external view returns (uint256) {
        if (_token == STAKE_TOKEN) {
            return STAKE_TOKEN.balanceOf(address(this)) - amountStaked();
        }
        return _token.balanceOf(address(this));
    }

    function _stake(uint256 _amount, uint256 _seconds, address _source) internal {
        bool success = STAKE_TOKEN.transferFrom(_source, address(this), _amount);
        if (!success) {
            revert StakeVault__StakingFailed();
        }

        stakeManager.stake(_amount, _seconds);

        emit Staked(_source, address(this), _amount, _seconds);
    }

    function _unstake(uint256 _amount, address _destination) internal {
        stakeManager.unstake(_amount);
        bool success = STAKE_TOKEN.transfer(_destination, _amount);
        if (!success) {
            revert StakeVault__UnstakingFailed();
        }
    }

    function _exit(address _destination) internal {
        if (IStakeManager.isTrustedCodehash(this.codehash)) {
            revert StakeVault__LeaveNotAvailable();
        }
        stakeManager.exit();
        STAKE_TOKEN.transferFrom(address(this), _destination, STAKE_TOKEN.balanceOf(address(this)));
    }

    function _withdraw(IERC20 _token, uint256 _amount, address _destination) internal {
        if (_token == STAKE_TOKEN && STAKE_TOKEN.balanceOf(address(this)) - amountStaked() < _amount) {
            revert StakeVault__NoEnoughAvailableBalance();
        }
        _token.transfer(_destination, _amount);
    }

    function _withdraw(uint256 _amount, address payable _destination) internal {
        _destination.transfer(_amount);
    }

    function amountStaked() public view returns (uint256) {
        return stakeManager.getStakedBalance(address(this));
    }
}
