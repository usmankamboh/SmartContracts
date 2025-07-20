// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
import "./Initializable.sol";
abstract contract NFTMarketAuction is Initializable {
  uint256 private nextAuctionId;
  function _initializeNFTMarketAuction() internal onlyInitializing {
    nextAuctionId = 1;
  }
  function _getNextAndIncrementAuctionId() internal returns (uint256) {
    // AuctionId cannot overflow 256 bits.
    unchecked {
      return nextAuctionId++;
    }
  }
  uint256[1000] private __gap;
}