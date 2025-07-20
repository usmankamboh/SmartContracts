// SPDX-License-Identifier: MIT 
pragma solidity 0.8.15;
import "./AddressUpgradeable.sol";
import "./NFTMarketFees.sol";
import "./IERC721.sol";
error NFTMarketOffer_Cannot_Be_Made_While_In_Auction();
// currentOfferAmount The current highest offer available for this NFT.
error NFTMarketOffer_Offer_Below_Min_Amount(uint256 currentOfferAmount);
// expiry The time at which the offer had expired.
error NFTMarketOffer_Offer_Expired(uint256 expiry);
// currentOfferFrom The address of the collector which has made the current highest offer.
error NFTMarketOffer_Offer_From_Does_Not_Match(address currentOfferFrom);
// minOfferAmount The minimum amount that must be offered in order for it to be accepted.
error NFTMarketOffer_Offer_Must_Be_At_Least_Min_Amount(uint256 minOfferAmount);
error NFTMarketOffer_Reason_Required();
error NFTMarketOffer_Provided_Contract_And_TokenId_Count_Must_Match();
abstract contract NFTMarketOffer is NFTMarketFees {
  using AddressUpgradeable for address;
  // Stores offer details for a specific NFT.
  struct Offer {
    // Slot 1: When increasing an offer, only this slot is updated.
    // The expiration timestamp of when this offer expires.
    uint32 expiration;
    // The amount, in wei, of the highest offer.
    uint96 amount;
    // First slot (of 16B) used for the offerReferrerAddress.
    // The offerReferrerAddress is the address used to pay the
    // referrer on an accepted offer.
    uint128 offerReferrerAddressSlot0;
    // Slot 2: When the buyer changes, both slots need updating
    // The address of the collector who made this offer.
    address buyer;
    // Second slot (of 4B) used for the offerReferrerAddress.
    uint32 offerReferrerAddressSlot1;
    // 96 bits (12B) are available in slot 1.
  }
  // Stores the highest offer for each NFT.
  mapping(address => mapping(uint256 => Offer)) private nftContractToIdToOffer;
  event OfferAccepted(
    address indexed nftContract,
    uint256 indexed tokenId,
    address indexed buyer,
    address seller,
    uint256 protocolFee,
    uint256 creatorFee,
    uint256 sellerRev
  );
  event OfferCanceledByAdmin(address indexed nftContract, uint256 indexed tokenId, string reason);
  event OfferInvalidated(address indexed nftContract, uint256 indexed tokenId);
  event OfferMade(
    address indexed nftContract,
    uint256 indexed tokenId,
    address indexed buyer,
    uint256 amount,
    uint256 expiration
  );
  function acceptOffer(
    address nftContract,
    uint256 tokenId,
    address offerFrom,
    uint256 minAmount
  ) external nonReentrant {
    Offer storage offer = nftContractToIdToOffer[nftContract][tokenId];
    // Validate offer expiry and amount
    if (offer.expiration < block.timestamp) {
      revert NFTMarketOffer_Offer_Expired(offer.expiration);
    } else if (offer.amount < minAmount) {
      revert NFTMarketOffer_Offer_Below_Min_Amount(offer.amount);
    }
    // Validate the buyer
    if (offer.buyer != offerFrom) {
      revert NFTMarketOffer_Offer_From_Does_Not_Match(offer.buyer);
    }
    _acceptOffer(nftContract, tokenId);
  }
  function adminCancelOffers(
    address[] calldata nftContracts,
    uint256[] calldata tokenIds,
    string calldata reason
  ) external onlyAdmin nonReentrant {
    if (bytes(reason).length == 0) {
      revert NFTMarketOffer_Reason_Required();
    }
    if (nftContracts.length != tokenIds.length) {
      revert NFTMarketOffer_Provided_Contract_And_TokenId_Count_Must_Match();
    }
    // The array length cannot overflow 256 bits
    unchecked {
      for (uint256 i = 0; i < nftContracts.length; ++i) {
        Offer memory offer = nftContractToIdToOffer[nftContracts[i]][tokenIds[i]];
        delete nftContractToIdToOffer[nftContracts[i]][tokenIds[i]];
        if (offer.expiration >= block.timestamp) {
          // Unlock from escrow and emit an event only if the offer is still active
          seth.marketUnlockFor(offer.buyer, offer.expiration, offer.amount);
          emit OfferCanceledByAdmin(nftContracts[i], tokenIds[i], reason);
        }
        // Else continue on so the rest of the batch transaction can process successfully
      }
    }
  }
  function makeOfferV2(
    address nftContract,
    uint256 tokenId,
    uint256 amount,
    address payable referrer
  ) public payable returns (uint256 expiration) {
    // If there is a buy price set at this price or lower, accept that instead.
    if (_autoAcceptBuyPrice(nftContract, tokenId, amount)) {
      // If the buy price is accepted, `0` is returned as the expiration since that's n/a.
      return 0;
    }
    if (_isInActiveAuction(nftContract, tokenId)) {
      revert NFTMarketOffer_Cannot_Be_Made_While_In_Auction();
    }
    Offer storage offer = nftContractToIdToOffer[nftContract][tokenId];
    if (offer.expiration < block.timestamp) {
      // This is a new offer for the NFT (no other offer found or the previous offer expired)
      // Lock the offer amount in SETH until the offer expires in 24-25 hours.
      expiration = seth.marketLockupFor{ value: msg.value }(msg.sender, amount);
    } else {
      // A previous offer exists and has not expired
      uint256 minIncrement = _getMinIncrement(offer.amount);
      if (amount < minIncrement) {
        // A non-trivial increase in price is required to avoid sniping
        revert NFTMarketOffer_Offer_Must_Be_At_Least_Min_Amount(minIncrement);
      }
      // Unlock the previous offer so that the SETH tokens are available for other offers or to transfer / withdraw
      // and lock the new offer amount in SETH until the offer expires in 24-25 hours.
      expiration = seth.marketChangeLockup{ value: msg.value }(
        offer.buyer,
        offer.expiration,
        offer.amount,
        msg.sender,
        amount
      );
    }
    // Record offer details
    offer.buyer = msg.sender;
    // The SETH contract guarantees that the expiration fits into 32 bits.
    offer.expiration = uint32(expiration);
    // `amount` is capped by the ETH provided, which cannot realistically overflow 96 bits.
    offer.amount = uint96(amount);
    // Set offerReferrerAddressSlot0 to the first 16B of the referrer address.
    // By shifting the referrer 32 bits to the right we obtain the first 16B.
    offer.offerReferrerAddressSlot0 = uint128(uint160(address(referrer)) >> 32);
    // Set offerReferrerAddressSlot1 to the last 4B of the referrer address.
    // By casting the referrer address to 32bits we discard the first 16B.
    offer.offerReferrerAddressSlot1 = uint32(uint160(address(referrer)));
    emit OfferMade(nftContract, tokenId, msg.sender, amount, expiration);
  }
  function makeOffer(
    address nftContract,
    uint256 tokenId,
    uint256 amount
  ) external payable returns (uint256 expiration) {
    expiration = makeOfferV2(nftContract, tokenId, amount, payable(0));
  }
  function _acceptOffer(address nftContract, uint256 tokenId) private {
    Offer memory offer = nftContractToIdToOffer[nftContract][tokenId];
    // Remove offer
    delete nftContractToIdToOffer[nftContract][tokenId];
    // Withdraw ETH from the buyer's account in the SETH token contract.
    seth.marketWithdrawLocked(offer.buyer, offer.expiration, offer.amount);
    // Transfer the NFT to the buyer.
    try
      IERC721(nftContract).transferFrom(msg.sender, offer.buyer, tokenId) // solhint-disable-next-line no-empty-blocks
    {
      // NFT was in the seller's wallet so the transfer is complete.
    } catch {
      // If the transfer fails then attempt to transfer from escrow instead.
      // This should revert if `msg.sender` is not the owner of this NFT.
      _transferFromEscrow(nftContract, tokenId, offer.buyer, msg.sender);
    }
    // Distribute revenue for this sale leveraging the ETH received from the SETH contract in the line above.
    (uint256 protocolFee, uint256 creatorFee, uint256 sellerRev) = _distributeFunds(
      nftContract,
      tokenId,
      payable(msg.sender),
      offer.amount,
      _getOfferReferrerFromSlots(offer.offerReferrerAddressSlot0, offer.offerReferrerAddressSlot1)
    );

    emit OfferAccepted(nftContract, tokenId, offer.buyer, msg.sender, protocolFee, creatorFee, sellerRev);
  }
  function _beforeAuctionStarted(address nftContract, uint256 tokenId) internal virtual override {
    _invalidateOffer(nftContract, tokenId);
    super._beforeAuctionStarted(nftContract, tokenId);
  }
  function _autoAcceptOffer(
    address nftContract,
    uint256 tokenId,
    uint256 minAmount
  ) internal override returns (bool) {
    Offer storage offer = nftContractToIdToOffer[nftContract][tokenId];
    if (offer.expiration < block.timestamp || offer.amount < minAmount) {
      // No offer found, the most recent offer is now expired, or the highest offer is below the minimum amount.
      return false;
    }
    _acceptOffer(nftContract, tokenId);
    return true;
  }
  function _cancelSendersOffer(address nftContract, uint256 tokenId) internal override {
    Offer storage offer = nftContractToIdToOffer[nftContract][tokenId];
    if (offer.buyer == msg.sender) {
      _invalidateOffer(nftContract, tokenId);
    }
  }
  function _invalidateOffer(address nftContract, uint256 tokenId) private {
    if (nftContractToIdToOffer[nftContract][tokenId].expiration >= block.timestamp) {
      // An offer was found and it has not already expired
      Offer memory offer = nftContractToIdToOffer[nftContract][tokenId];
      // Remove offer
      delete nftContractToIdToOffer[nftContract][tokenId];
      // Unlock the offer so that the SETH tokens are available for other offers or to transfer / withdraw
      seth.marketUnlockFor(offer.buyer, offer.expiration, offer.amount);
      emit OfferInvalidated(nftContract, tokenId);
    }
  }
  function getMinOfferAmount(address nftContract, uint256 tokenId) external view returns (uint256 minimum) {
    Offer storage offer = nftContractToIdToOffer[nftContract][tokenId];
    if (offer.expiration >= block.timestamp) {
      return _getMinIncrement(offer.amount);
    }
    // Absolute min is anything > 0
    return 1;
  }
  function getOffer(address nftContract, uint256 tokenId)
    external
    view
    returns (
      address buyer,
      uint256 expiration,
      uint256 amount
    )
  {
    Offer storage offer = nftContractToIdToOffer[nftContract][tokenId];
    if (offer.expiration < block.timestamp) {
      // Offer not found or has expired
      return (address(0), 0, 0);
    }
    // An offer was found and it has not yet expired.
    return (offer.buyer, offer.expiration, offer.amount);
  }
  function getOfferReferrer(address nftContract, uint256 tokenId) external view returns (address payable referrer) {
    Offer storage offer = nftContractToIdToOffer[nftContract][tokenId];
    if (offer.expiration < block.timestamp) {
      // Offer not found or has expired
      return payable(0);
    }
    return _getOfferReferrerFromSlots(offer.offerReferrerAddressSlot0, offer.offerReferrerAddressSlot1);
  }
  function _getOfferReferrerFromSlots(uint128 offerReferrerAddressSlot0, uint32 offerReferrerAddressSlot1)
    private
    pure
    returns (address payable referrer)
  {
    referrer = payable(address((uint160(offerReferrerAddressSlot0) << 32) | uint160(offerReferrerAddressSlot1)));
  }
  uint256[1000] private __gap;
}