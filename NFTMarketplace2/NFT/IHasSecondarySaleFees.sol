// SPDX-License-Identifier: MIT 
pragma solidity 0.8.15;
interface IHasSecondarySaleFees {
  function getFeeRecipients(uint256 id) external view returns (address payable[] memory);
  function getFeeBps(uint256 id) external view returns (uint256[] memory);
}