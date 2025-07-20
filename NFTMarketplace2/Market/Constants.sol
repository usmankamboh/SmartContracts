// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
abstract contract Constants {
  uint256 internal constant BASIS_POINTS = 10000;
  uint256 internal constant MAX_ROYALTY_RECIPIENTS = 5;
  uint256 internal constant MIN_PERCENT_INCREMENT_DENOMINATOR = BASIS_POINTS / 1000;
  uint256 internal constant READ_ONLY_GAS_LIMIT = 40000;
  uint256 internal constant SEND_VALUE_GAS_LIMIT_MULTIPLE_RECIPIENTS = 210000;
  uint256 internal constant SEND_VALUE_GAS_LIMIT_SINGLE_RECIPIENT = 20000;
}