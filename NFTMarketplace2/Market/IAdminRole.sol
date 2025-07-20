// SPDX-License-Identifier: MIT 
pragma solidity 0.8.15;
interface IAdminRole {
  function isAdmin(address account) external view returns (bool);
}