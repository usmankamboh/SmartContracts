// SPDX-License-Identifier: MIT 
pragma solidity 0.8.15;
interface IFNDNFTMarket {
  function getFeeConfig()
    external
    view
    returns (
      uint256 primaryFeeBasisPoints,
      uint256 secondaryFeeBasisPoints,
      uint256 secondaryCreatorFeeBasisPoints
    );
}