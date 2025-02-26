// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IRewardProvider } from "./interfaces/IRewardProvider.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Karma is ERC20, Ownable2Step {
    using EnumerableSet for EnumerableSet.AddressSet;

    string public constant NAME = "Karma";
    string public constant SYMBOL = "KARMA";

    uint256 allProvidersAllocatedSupply;

    EnumerableSet.AddressSet private rewardProviders;
    mapping(address => uint256) public rewardProviderAllocatedSupply;

    error Karma__TransfersNotAllowed();
    error Karma__MintAllowanceExceeded();
    error Karma__ProviderAlreadyAdded();
    error Karma__UnknownProvider();

    event RewardProviderAdded(address provider);

    constructor() ERC20(NAME, SYMBOL) Ownable(msg.sender) { }

    function addRewardProvider(address provider) external onlyOwner {
        if (rewardProviders.contains(provider)) {
            revert Karma__ProviderAlreadyAdded();
        }

        rewardProviders.add(address(provider));
        emit RewardProviderAdded(provider);
    }

    function removeRewardProvider(address provider) external onlyOwner {
        if (!rewardProviders.contains(provider)) {
            revert Karma__UnknownProvider();
        }

        rewardProviders.remove(provider);
    }

    function setReward(address rewardsProvider, uint256 amount, uint256 duration) external onlyOwner {
        if (!rewardProviders.contains(rewardsProvider)) {
            revert Karma__UnknownProvider();
        }

        rewardProviderAllocatedSupply[rewardsProvider] = amount;
        allProvidersAllocatedSupply += amount;
        IRewardProvider(rewardsProvider).setReward(amount, duration);
    }

    function getRewardProviders() external view returns (address[] memory) {
        return rewardProviders.values();
    }

    function _totalSupply() public view returns (uint256) {
        return super.totalSupply() + _externalSupply();
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply();
    }

    function mint(address account, uint256 amount) external onlyOwner {
        if (amount > _mintAllowance()) {
            revert Karma__MintAllowanceExceeded();
        }

        _mint(account, amount);
    }

    function _mintAllowance() internal view returns (uint256) {
        uint256 maxSupply = _externalSupply() * 3;
        uint256 fullTotalSupply = _totalSupply();
        if (maxSupply <= fullTotalSupply) {
            return 0;
        }

        return maxSupply - fullTotalSupply;
    }

    function mintAllowance() public view returns (uint256) {
        return _mintAllowance();
    }

    function _externalSupply() internal view returns (uint256) {
        uint256 externalSupply;

        for (uint256 i = 0; i < rewardProviders.length(); i++) {
            IRewardProvider provider = IRewardProvider(rewardProviders.at(i));
            uint256 supply = provider.totalRewardsSupply();
            if (supply > rewardProviderAllocatedSupply[address(provider)]) {
                supply = rewardProviderAllocatedSupply[address(provider)];
            }

            externalSupply += supply;
        }

        return externalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        uint256 externalBalance;

        for (uint256 i = 0; i < rewardProviders.length(); i++) {
            IRewardProvider provider = rewardProviders.at(i);
            externalBalance += provider.rewardsBalanceOfAccount(account);
        }

        return super.balanceOf(account) + externalBalance;
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

    function allowance(address, address) public pure override returns (uint256) {
        return 0;
    }
}
