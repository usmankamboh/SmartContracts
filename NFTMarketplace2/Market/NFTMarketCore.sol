// SPDX-License-Identifier: MIT 
pragma solidity 0.8.15;
import "./IERC721.sol";
import "./AddressUpgradeable.sol";
import "./Initializable.sol";
import "./Constants.sol";
import "./ISethMarket.sol";
error NFTMarketCore_SETH_Address_Is_Not_A_Contract();
error NFTMarketCore_Only_SETH_Can_Transfer_ETH();
error NFTMarketCore_Seller_Not_Found();
abstract contract NFTMarketCore is Constants, Initializable {
  using AddressUpgradeable for address;
  // The SETH ERC-20 token for managing escrow and lockup.
  ISethMarket internal immutable seth;
  constructor(address _seth) {
    seth = ISethMarket(_seth);
  }
  receive() external payable {
  }
  function _autoAcceptBuyPrice(
    address nftContract,
    uint256 tokenId,
    uint256 amount
  ) internal virtual returns (bool);
  function _autoAcceptOffer(
    address nftContract,
    uint256 tokenId,
    uint256 minAmount
  ) internal virtual returns (bool);
  function _beforeAuctionStarted(
    address, /*nftContract*/
    uint256 /*tokenId*/ // solhint-disable-next-line no-empty-blocks
  ) internal virtual {
    // No-op
  }
  function _cancelSendersOffer(address nftContract, uint256 tokenId) internal virtual;
  function _transferFromEscrow(
    address nftContract,
    uint256 tokenId,
    address recipient,
    address authorizeSeller
  ) internal virtual {
    if (authorizeSeller != address(0)) {
      revert NFTMarketCore_Seller_Not_Found();
    }
    IERC721(nftContract).transferFrom(address(this), recipient, tokenId);
  }
  function _transferFromEscrowIfAvailable(
    address nftContract,
    uint256 tokenId,
    address recipient
  ) internal virtual {
    IERC721(nftContract).transferFrom(address(this), recipient, tokenId);
  }
  function _transferToEscrow(address nftContract, uint256 tokenId) internal virtual {
    IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
  }
  function getSETHAddress() external view returns (address sethAddress) {
    sethAddress = address(seth);
  }
  function _getMinIncrement(uint256 currentAmount) internal pure returns (uint256) {
    uint256 minIncrement = currentAmount;
    unchecked {
      minIncrement /= MIN_PERCENT_INCREMENT_DENOMINATOR;
    }
    if (minIncrement == 0) {
      return currentAmount + 1;
    }
    return minIncrement + currentAmount;
  }
  function _getSellerFor(address nftContract, uint256 tokenId) internal view virtual returns (address payable seller) {
    seller = payable(IERC721(nftContract).ownerOf(tokenId));
  }
  function _isInActiveAuction(address nftContract, uint256 tokenId) internal view virtual returns (bool);
  uint256[950] private __gap;
}