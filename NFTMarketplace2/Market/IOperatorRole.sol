// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
interface IOperatorRole {
  function isOperator(address account) external view returns (bool);
}