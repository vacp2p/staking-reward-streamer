// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Karma } from "./Karma.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract KarmaWithAccessControl is Karma, AccessControlUpgradeable {
    /// @notice Emitted sender does not have the required role
    error KarmaWithAccessControl__Unauthorized();

    /// @notice Operator role keccak256("OPERATOR_ROLE")
    bytes32 public constant OPERATOR_ROLE = 0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929;
    /// @notice Gap for future variable additions
    // solhint-disable-next-line var-name-mixedcase
    uint256[15] private __gap_KarmaWithAccessControl;

    /// @notice Modifier to check if sender is admin or operator
    modifier onlyAdminOrOperator() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender) && !hasRole(OPERATOR_ROLE, msg.sender)) {
            revert KarmaWithAccessControl__Unauthorized();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                           USER-FACING FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the contract with the provided owner.
     * @dev This function needs to be called after the contract has been upgraded.
     * @dev Sets up the `DEFAULT_ADMIN_ROLE` for the current owner.
     */
    // function initializeAccessControl() external reinitializer(2) onlyOwner {
    function initializeAccessControl() external reinitializer(2) onlyOwner {
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, owner());
    }

    /**
     * @inheritdoc Karma
     * @dev Added role-based access control with DEFAULT_ADMIN_ROLE.
     */
    function addRewardDistributor(address distributor) public override onlyRole(DEFAULT_ADMIN_ROLE) {
        _addRewardDistributor(distributor);
    }

    /**
     * @inheritdoc Karma
     * @dev Added role-based access control with DEFAULT_ADMIN_ROLE.
     */
    function removeRewardDistributor(address distributor) public override onlyRole(DEFAULT_ADMIN_ROLE) {
        _removeRewardDistributor(distributor);
    }

    /**
     * @inheritdoc Karma
     * @dev Added role-based access control with DEFAULT_ADMIN_ROLE and OPERATOR_ROLE.
     */
    function setReward(address distributor, uint256 amount, uint256 duration) public override onlyAdminOrOperator {
        _setReward(distributor, amount, duration);
    }

    /**
     * @inheritdoc Karma
     * @dev Added role-based access control with DEFAULT_ADMIN_ROLE and OPERATOR_ROLE.
     */
    function mint(address account, uint256 amount) public override onlyAdminOrOperator {
        _mint(account, amount);
    }

    /*//////////////////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Authorizes the upgrade of the contract.
     * @dev Enables owner and accounts with DEFAULT_ADMIN_ROLE to upgrade the contract.
     */
    function _authorizeUpgrade(address) internal view virtual override {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert KarmaWithAccessControl__Unauthorized();
        }
    }
}
