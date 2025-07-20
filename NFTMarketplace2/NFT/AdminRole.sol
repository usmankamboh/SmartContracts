// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
import "./IAdminRole.sol";
import "./TreasuryNode.sol";
abstract contract AdminRole is TreasuryNode {
  // This file uses 0 data slots (other than what's included via TreasuryNode)
  modifier onlyAdmin() {
    require(_isAdmin(), "AdminRole: caller does not have the Admin role");
    _;
  }
  function _isAdmin() internal view returns (bool) {
    return IAdminRole(getTreasury()).isAdmin(msg.sender);
  }
}