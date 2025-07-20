// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
interface IGetRoyalties {
  function getRoyalties(uint256 tokenId)
    external
    view
    returns (address payable[] memory recipients, uint256[] memory feesInBasisPoints);
}