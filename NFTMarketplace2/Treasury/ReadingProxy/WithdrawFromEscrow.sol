// SPDX-License-Identifier: MIT 

pragma solidity 0.8.15;

import "./ISendValueWithFallbackWithdraw.sol";
import "./AdminRole.sol";

/**
 * @notice Allows recovery of funds that were not successfully transferred directly by the market.
 */
abstract contract WithdrawFromEscrow is AdminRole {
  function withdrawFromEscrow(ISendValueWithFallbackWithdraw market) external onlyAdmin {
    market.withdraw();
  }
}