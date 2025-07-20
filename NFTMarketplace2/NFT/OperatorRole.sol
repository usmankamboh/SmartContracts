// SPDX-License-Identifier: MIT 
pragma solidity 0.8.15;
import "./IOperatorRole.sol";
import "./TreasuryNode.sol";
abstract contract OperatorRole is TreasuryNode {
  // This file uses 0 data slots (other than what's included via TreasuryNode)
  function _isOperator() internal view returns (bool) {
    return IOperatorRole(getTreasury()).isOperator(msg.sender);
  }
}