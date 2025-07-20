// SPDX-License-Identifier: MIT 
pragma solidity 0.8.15;
import "./AddressUpgradeable.sol";
import "./NFTMarketFees.sol";
// buyPrice The current buy price set for this NFT.
error NFTMarketBuyPrice_Cannot_Buy_At_Lower_Price(uint256 buyPrice);
error NFTMarketBuyPrice_Cannot_Buy_Unset_Price();
error NFTMarketBuyPrice_Cannot_Cancel_Unset_Price();
// owner The current owner of this NFT.
error NFTMarketBuyPrice_Only_Owner_Can_Cancel_Price(address owner);
// owner The current owner of this NFT.
error NFTMarketBuyPrice_Only_Owner_Can_Set_Price(address owner);
error NFTMarketBuyPrice_Price_Already_Set();
error NFTMarketBuyPrice_Price_Too_High();
// seller The current owner of this NFT.
error NFTMarketBuyPrice_Seller_Mismatch(address seller);
abstract contract NFTMarketBuyPrice is NFTMarketFees {
  using AddressUpgradeable for address payable;
  // Stores the buy price details for a specific NFT.
  // The struct is packed into a single slot to optimize gas.
  struct BuyPrice {
    // The current owner of this NFT which set a buy price.
    // A zero price is acceptable so a non-zero address determines whether a price has been set.
    address payable seller;
    // The current buy price set for this NFT.
    uint96 price;
  }
  // Stores the current buy price for each NFT.
  mapping(address => mapping(uint256 => BuyPrice)) private nftContractToTokenIdToBuyPrice;
  event BuyPriceAccepted(
    address indexed nftContract,
    uint256 indexed tokenId,
    address indexed seller,
    address buyer,
    uint256 protocolFee,
    uint256 creatorFee,
    uint256 sellerRev
  );
  event BuyPriceCanceled(address indexed nftContract, uint256 indexed tokenId);
  event BuyPriceInvalidated(address indexed nftContract, uint256 indexed tokenId);
  event BuyPriceSet(address indexed nftContract, uint256 indexed tokenId, address indexed seller, uint256 price);
  function buy(
    address nftContract,
    uint256 tokenId,
    uint256 maxPrice
  ) external payable {
    buyV2(nftContract, tokenId, maxPrice, payable(0));
  }
  function buyV2(
    address nftContract,
    uint256 tokenId,
    uint256 maxPrice,
    address payable referrer
  ) public payable {
    BuyPrice storage buyPrice = nftContractToTokenIdToBuyPrice[nftContract][tokenId];
    if (buyPrice.price > maxPrice) {
      revert NFTMarketBuyPrice_Cannot_Buy_At_Lower_Price(buyPrice.price);
    } else if (buyPrice.seller == address(0)) {
      revert NFTMarketBuyPrice_Cannot_Buy_Unset_Price();
    }
    _buy(nftContract, tokenId, referrer);
  }
  function cancelBuyPrice(address nftContract, uint256 tokenId) external nonReentrant {
    address seller = nftContractToTokenIdToBuyPrice[nftContract][tokenId].seller;
    if (seller == address(0)) {
      // This check is redundant with the next one, but done in order to provide a more clear error message.
      revert NFTMarketBuyPrice_Cannot_Cancel_Unset_Price();
    } else if (seller != msg.sender) {
      revert NFTMarketBuyPrice_Only_Owner_Can_Cancel_Price(seller);
    }
    // Remove the buy price
    delete nftContractToTokenIdToBuyPrice[nftContract][tokenId];
    // Transfer the NFT back to the owner if it is not listed in auction.
    _transferFromEscrowIfAvailable(nftContract, tokenId, msg.sender);
    emit BuyPriceCanceled(nftContract, tokenId);
  }
  function setBuyPrice(
    address nftContract,
    uint256 tokenId,
    uint256 price
  ) external nonReentrant {
    // If there is a valid offer at this price or higher, accept that instead.
    if (_autoAcceptOffer(nftContract, tokenId, price)) {
      return;
    }
    if (price > type(uint96).max) {
      // This ensures that no data is lost when storing the price as `uint96`.
      revert NFTMarketBuyPrice_Price_Too_High();
    }
    BuyPrice storage buyPrice = nftContractToTokenIdToBuyPrice[nftContract][tokenId];
    address seller = buyPrice.seller;
    if (buyPrice.price == price && seller != address(0)) {
      revert NFTMarketBuyPrice_Price_Already_Set();
    }
    // Store the new price for this NFT.
    buyPrice.price = uint96(price);
    if (seller == address(0)) {
      // Transfer the NFT into escrow, if it's already in escrow confirm the `msg.sender` is the owner.
      _transferToEscrow(nftContract, tokenId);
      // The price was not previously set for this NFT, store the seller.
      buyPrice.seller = payable(msg.sender);
    } else if (seller != msg.sender) {
      // Buy price was previously set by a different user
      revert NFTMarketBuyPrice_Only_Owner_Can_Set_Price(seller);
    }
    emit BuyPriceSet(nftContract, tokenId, msg.sender, price);
  }
  function _autoAcceptBuyPrice(
    address nftContract,
    uint256 tokenId,
    uint256 maxPrice
  ) internal override returns (bool) {
    BuyPrice storage buyPrice = nftContractToTokenIdToBuyPrice[nftContract][tokenId];
    if (buyPrice.seller == address(0) || buyPrice.price > maxPrice) {
      // No buy price was found, or the price is too high.
      return false;
    }
    _buy(nftContract, tokenId, payable(0));
    return true;
  }
  function _beforeAuctionStarted(address nftContract, uint256 tokenId) internal virtual override {
    BuyPrice storage buyPrice = nftContractToTokenIdToBuyPrice[nftContract][tokenId];
    if (buyPrice.seller != address(0)) {
      // A buy price was set for this NFT, invalidate it.
      _invalidateBuyPrice(nftContract, tokenId);
    }
    super._beforeAuctionStarted(nftContract, tokenId);
  }
  function _buy(
    address nftContract,
    uint256 tokenId,
    address payable referrer
  ) private nonReentrant {
    BuyPrice memory buyPrice = nftContractToTokenIdToBuyPrice[nftContract][tokenId];
    // Remove the buy now price
    delete nftContractToTokenIdToBuyPrice[nftContract][tokenId];
    // Cancel the buyer's offer if there is one in order to free up their SETH balance
    // even if they don't need the SETH for this specific purchase.
    _cancelSendersOffer(nftContract, tokenId);
    if (buyPrice.price > msg.value) {
      // Withdraw additional ETH required from their available SETH balance.
      unchecked {
        // The if above ensures delta will not underflow.
        uint256 delta = buyPrice.price - msg.value;
        // Withdraw ETH from the buyer's account in the SETH token contract,
        // making the ETH available for `_distributeFunds` below.
        seth.marketWithdrawFrom(msg.sender, delta);
      }
    } else if (buyPrice.price < msg.value) {
      // Return any surplus funds to the buyer.
      unchecked {
        // The if above ensures this will not underflow
        payable(msg.sender).sendValue(msg.value - buyPrice.price);
      }
    }
    // Transfer the NFT to the buyer.
    // The seller was already authorized when the buyPrice was set originally set.
    _transferFromEscrow(nftContract, tokenId, msg.sender, address(0));
    // Distribute revenue for this sale.
    (uint256 protocolFee, uint256 creatorFee, uint256 sellerRev) = _distributeFunds(
      nftContract,
      tokenId,
      buyPrice.seller,
      buyPrice.price,
      referrer
    );
    emit BuyPriceAccepted(nftContract, tokenId, buyPrice.seller, msg.sender, protocolFee, creatorFee, sellerRev);
  }
  function _invalidateBuyPrice(address nftContract, uint256 tokenId) private {
    delete nftContractToTokenIdToBuyPrice[nftContract][tokenId];
    emit BuyPriceInvalidated(nftContract, tokenId);
  }
  function _transferFromEscrow(
    address nftContract,
    uint256 tokenId,
    address recipient,
    address authorizeSeller
  ) internal virtual override {
    address seller = nftContractToTokenIdToBuyPrice[nftContract][tokenId].seller;
    if (seller != address(0)) {
      // A buy price was set for this NFT
      if (seller != authorizeSeller) {
        // When there is a buy price set, the `buyPrice.seller` is the owner of the NFT.
        revert NFTMarketBuyPrice_Seller_Mismatch(seller);
      }
      // The seller authorization has been confirmed.
      authorizeSeller = address(0);
      // Invalidate the buy price as the NFT will no longer be in escrow.
      _invalidateBuyPrice(nftContract, tokenId);
    }
    super._transferFromEscrow(nftContract, tokenId, recipient, authorizeSeller);
  }
  function _transferFromEscrowIfAvailable(
    address nftContract,
    uint256 tokenId,
    address recipient
  ) internal virtual override {
    address seller = nftContractToTokenIdToBuyPrice[nftContract][tokenId].seller;
    if (seller == address(0)) {
      // A buy price has been set for this NFT so it should remain in escrow.
      super._transferFromEscrowIfAvailable(nftContract, tokenId, recipient);
    }
  }
  function _transferToEscrow(address nftContract, uint256 tokenId) internal virtual override {
    address seller = nftContractToTokenIdToBuyPrice[nftContract][tokenId].seller;
    if (seller == address(0)) {
      // The NFT is not in escrow for buy now.
      super._transferToEscrow(nftContract, tokenId);
    } else if (seller != msg.sender) {
      // When there is a buy price set, the `seller` is the owner of the NFT.
      revert NFTMarketBuyPrice_Seller_Mismatch(seller);
    }
  }
  function getBuyPrice(address nftContract, uint256 tokenId) external view returns (address seller, uint256 price) {
    seller = nftContractToTokenIdToBuyPrice[nftContract][tokenId].seller;
    if (seller == address(0)) {
      return (seller, type(uint256).max);
    }
    price = nftContractToTokenIdToBuyPrice[nftContract][tokenId].price;
  }
  function _getSellerFor(address nftContract, uint256 tokenId)
    internal
    view
    virtual
    override
    returns (address payable seller)
  {
    seller = nftContractToTokenIdToBuyPrice[nftContract][tokenId].seller;
    if (seller == address(0)) {
      seller = super._getSellerFor(nftContract, tokenId);
    }
  }
  uint256[1000] private __gap;
}