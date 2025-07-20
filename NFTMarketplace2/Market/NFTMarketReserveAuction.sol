// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
import "./NFTMarketAuction.sol";
import "./NFTMarketFees.sol";
//  auctionId The already listed auctionId for this NFT.
error NFTMarketReserveAuction_Already_Listed(uint256 auctionId);
//  minAmount The minimum amount that must be bid in order for it to be accepted.
error NFTMarketReserveAuction_Bid_Must_Be_At_Least_Min_Amount(uint256 minAmount);
error NFTMarketReserveAuction_Cannot_Admin_Cancel_Without_Reason();
//  reservePrice The current reserve price.
error NFTMarketReserveAuction_Cannot_Bid_Lower_Than_Reserve_Price(uint256 reservePrice);
//  endTime The timestamp at which the auction had ended.
error NFTMarketReserveAuction_Cannot_Bid_On_Ended_Auction(uint256 endTime);
error NFTMarketReserveAuction_Cannot_Bid_On_Nonexistent_Auction();
error NFTMarketReserveAuction_Cannot_Cancel_Nonexistent_Auction();
error NFTMarketReserveAuction_Cannot_Finalize_Already_Settled_Auction();
//  endTime The timestamp at which the auction will end.
error NFTMarketReserveAuction_Cannot_Finalize_Auction_In_Progress(uint256 endTime);
error NFTMarketReserveAuction_Cannot_Rebid_Over_Outstanding_Bid();
error NFTMarketReserveAuction_Cannot_Update_Auction_In_Progress();
//  maxDuration The maximum configuration for a duration of the auction, in seconds.
error NFTMarketReserveAuction_Exceeds_Max_Duration(uint256 maxDuration);
//  extensionDuration The extension duration, in seconds.
error NFTMarketReserveAuction_Less_Than_Extension_Duration(uint256 extensionDuration);
error NFTMarketReserveAuction_Must_Set_Non_Zero_Reserve_Price();
//  seller The current owner of the NFT.
error NFTMarketReserveAuction_Not_Matching_Seller(address seller);
//  owner The current owner of the NFT.
error NFTMarketReserveAuction_Only_Owner_Can_Update_Auction(address owner);
error NFTMarketReserveAuction_Price_Already_Set();
error NFTMarketReserveAuction_Too_Much_Value_Provided();
abstract contract NFTMarketReserveAuction is NFTMarketFees, NFTMarketAuction {
  //  The auction configuration for a specific NFT.
  struct ReserveAuction {
    //  The address of the NFT contract.
    address nftContract;
    //  The id of the NFT.
    uint256 tokenId;
    //  The owner of the NFT which listed it in auction.
    address payable seller;
    //  The duration for this auction.
    uint256 duration;
    //  The extension window for this auction.
    uint256 extensionDuration;
    //  The time at which this auction will not accept any new bids.
    /// @dev This is `0` until the first bid is placed.
    uint256 endTime;
    //  The current highest bidder in this auction.
    /// @dev This is `address(0)` until the first bid is placed.
    address payable bidder;
    //  The latest price of the NFT in this auction.
    /// @dev This is set to the reserve price, and then to the highest bid once the auction has started.
    uint256 amount;
  }
  //  Stores the auction configuration for a specific NFT.
  /// @dev This allows us to modify the storage struct without changing external APIs.
  struct ReserveAuctionStorage {
    //  The address of the NFT contract.
    address nftContract;
    //  The id of the NFT.
    uint256 tokenId;
    //  The owner of the NFT which listed it in auction.
    address payable seller;
    //  First slot (of 12B) used for the bidReferrerAddress.
    // The bidReferrerAddress is the address used to pay the referrer on finalize.
    // This approach is used in order to pack storage, saving gas.
    uint96 bidReferrerAddressSlot0;
    // This field is no longer used.
    uint256 __gap_was_duration;
    // This field is no longer used.
    uint256 __gap_was_extensionDuration;
    //  The time at which this auction will not accept any new bids.
    // This is `0` until the first bid is placed.
    uint256 endTime;
    //  The current highest bidder in this auction.
    // This is `address(0)` until the first bid is placed.
    address payable bidder;
    //  Second slot (of 8B) used for the bidReferrerAddress.
    uint64 bidReferrerAddressSlot1;
    //  The latest price of the NFT in this auction.
    // This is set to the reserve price, and then to the highest bid once the auction has started.
    uint256 amount;
  }
  //  The auction configuration for a specific auction id.
  mapping(address => mapping(uint256 => uint256)) private nftContractToTokenIdToAuctionId;
  //  The auction id for a specific NFT.
  //  This is deleted when an auction is finalized or canceled.
  mapping(uint256 => ReserveAuctionStorage) private auctionIdToAuction;
  uint256[5] private __gap_was_config;
  //  How long an auction lasts for once the first bid has been received.
  uint256 private immutable DURATION;
  //  The window for auction extensions, any bid placed in the final 15 minutes
  // of an auction will reset the time remaining to 15 minutes.
  uint256 private constant EXTENSION_DURATION = 15 minutes;
  //  Caps the max duration that may be configured so that overflows will not occur.
  uint256 private constant MAX_MAX_DURATION = 1000 days;
  event ReserveAuctionBidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount, uint256 endTime);
  event ReserveAuctionCanceled(uint256 indexed auctionId);
  event ReserveAuctionCanceledByAdmin(uint256 indexed auctionId, string reason);
  event ReserveAuctionCreated(
    address indexed seller,
    address indexed nftContract,
    uint256 indexed tokenId,
    uint256 duration,
    uint256 extensionDuration,
    uint256 reservePrice,
    uint256 auctionId
  );
  event ReserveAuctionFinalized(
    uint256 indexed auctionId,
    address indexed seller,
    address indexed bidder,
    uint256 protocolFee,
    uint256 creatorFee,
    uint256 sellerRev
  );
  event ReserveAuctionInvalidated(uint256 indexed auctionId);
  event ReserveAuctionUpdated(uint256 indexed auctionId, uint256 reservePrice);
  //  Confirms that the reserve price is not zero.
  modifier onlyValidAuctionConfig(uint256 reservePrice) {
    if (reservePrice == 0) {
      revert NFTMarketReserveAuction_Must_Set_Non_Zero_Reserve_Price();
    }
    _;
  }
  constructor(uint256 duration) {
    DURATION = duration;
  }
  function adminCancelReserveAuction(uint256 auctionId, string calldata reason)
    external
    onlyAdmin
    nonReentrant
  {
    if (bytes(reason).length == 0) {
      revert NFTMarketReserveAuction_Cannot_Admin_Cancel_Without_Reason();
    }
    ReserveAuctionStorage memory auction = auctionIdToAuction[auctionId];
    if (auction.amount == 0) {
      revert NFTMarketReserveAuction_Cannot_Cancel_Nonexistent_Auction();
    }
    delete nftContractToTokenIdToAuctionId[auction.nftContract][auction.tokenId];
    delete auctionIdToAuction[auctionId];
    // Return the NFT to the owner.
    _transferFromEscrowIfAvailable(auction.nftContract, auction.tokenId, auction.seller);
    if (auction.bidder != address(0)) {
      // Refund the highest bidder if any bids were placed in this auction.
      _sendValueWithFallbackWithdraw(auction.bidder, auction.amount, SEND_VALUE_GAS_LIMIT_SINGLE_RECIPIENT);
    }
    emit ReserveAuctionCanceledByAdmin(auctionId, reason);
  }
  function cancelReserveAuction(uint256 auctionId) external nonReentrant {
    ReserveAuctionStorage memory auction = auctionIdToAuction[auctionId];
    if (auction.seller != msg.sender) {
      revert NFTMarketReserveAuction_Only_Owner_Can_Update_Auction(auction.seller);
    }
    if (auction.endTime != 0) {
      revert NFTMarketReserveAuction_Cannot_Update_Auction_In_Progress();
    }
    // Remove the auction.
    delete nftContractToTokenIdToAuctionId[auction.nftContract][auction.tokenId];
    delete auctionIdToAuction[auctionId];
    // Transfer the NFT unless it still has a buy price set.
    _transferFromEscrowIfAvailable(auction.nftContract, auction.tokenId, auction.seller);
    emit ReserveAuctionCanceled(auctionId);
  }
  function createReserveAuction(
    address nftContract,
    uint256 tokenId,
    uint256 reservePrice
  ) external nonReentrant onlyValidAuctionConfig(reservePrice) {
    uint256 auctionId = _getNextAndIncrementAuctionId();
    // If the `msg.sender` is not the owner of the NFT, transferring into escrow should fail.
    _transferToEscrow(nftContract, tokenId);
    // This check must be after _transferToEscrow in case auto-settle was required
    if (nftContractToTokenIdToAuctionId[nftContract][tokenId] != 0) {
      revert NFTMarketReserveAuction_Already_Listed(nftContractToTokenIdToAuctionId[nftContract][tokenId]);
    }
    // Store the auction details
    nftContractToTokenIdToAuctionId[nftContract][tokenId] = auctionId;
    ReserveAuctionStorage storage auction = auctionIdToAuction[auctionId];
    auction.nftContract = nftContract;
    auction.tokenId = tokenId;
    auction.seller = payable(msg.sender);
    auction.amount = reservePrice;
    emit ReserveAuctionCreated(msg.sender, nftContract, tokenId, DURATION, EXTENSION_DURATION, reservePrice, auctionId);
  }
  function finalizeReserveAuction(uint256 auctionId) external nonReentrant {
    if (auctionIdToAuction[auctionId].endTime == 0) {
      revert NFTMarketReserveAuction_Cannot_Finalize_Already_Settled_Auction();
    }
    _finalizeReserveAuction({ auctionId: auctionId, keepInEscrow: false });
  }
  function placeBid(uint256 auctionId) external payable {
    placeBidV2(auctionId, msg.value, payable(0));
  }
  function placeBidV2(
    uint256 auctionId,
    uint256 amount,
    address payable referrer
  ) public payable nonReentrant {
    ReserveAuctionStorage storage auction = auctionIdToAuction[auctionId];
    if (auction.amount == 0) {
      // No auction found
      revert NFTMarketReserveAuction_Cannot_Bid_On_Nonexistent_Auction();
    } else if (amount < msg.value) {
      // The amount is specified by the bidder, so if too much ETH is sent then something went wrong.
      revert NFTMarketReserveAuction_Too_Much_Value_Provided();
    }
    uint256 endTime = auction.endTime;
    // Store the bid referral
    if (referrer != address(0) || endTime != 0) {
      auction.bidReferrerAddressSlot0 = uint96(uint160(address(referrer)) >> 64);
      auction.bidReferrerAddressSlot1 = uint64(uint160(address(referrer)));
    }
    if (endTime == 0) {
      // This is the first bid, kicking off the auction.
      if (amount < auction.amount) {
        // The bid must be >= the reserve price.
        revert NFTMarketReserveAuction_Cannot_Bid_Lower_Than_Reserve_Price(auction.amount);
      }
      // Notify other market tools that an auction for this NFT has been kicked off.
      // The only state change before this call is potentially withdrawing funds from SETH.
      _beforeAuctionStarted(auction.nftContract, auction.tokenId);
      // Store the bid details.
      auction.amount = amount;
      auction.bidder = payable(msg.sender);
      // On the first bid, set the endTime to now + duration.
      unchecked {
        // Duration is always set to 24hrs so the below can't overflow.
        endTime = block.timestamp + DURATION;
      }
      auction.endTime = endTime;
    } else {
      if (endTime < block.timestamp) {
        // The auction has already ended.
        revert NFTMarketReserveAuction_Cannot_Bid_On_Ended_Auction(endTime);
      } else if (auction.bidder == msg.sender) {
        // We currently do not allow a bidder to increase their bid unless another user has outbid them first.
        revert NFTMarketReserveAuction_Cannot_Rebid_Over_Outstanding_Bid();
      } else {
        uint256 minIncrement = _getMinIncrement(auction.amount);
        if (amount < minIncrement) {
          // If this bid outbids another, it must be at least 10% greater than the last bid.
          revert NFTMarketReserveAuction_Bid_Must_Be_At_Least_Min_Amount(minIncrement);
        }
      }
      // Cache and update bidder state
      uint256 originalAmount = auction.amount;
      address payable originalBidder = auction.bidder;
      auction.amount = amount;
      auction.bidder = payable(msg.sender);
      unchecked {
        // When a bid outbids another, check to see if a time extension should apply.
        // We confirmed that the auction has not ended, so endTime is always >= the current timestamp.
        // Current time plus extension duration (always 15 mins) cannot overflow.
        uint256 endTimeWithExtension = block.timestamp + EXTENSION_DURATION;
        if (endTime < endTimeWithExtension) {
          endTime = endTimeWithExtension;
          auction.endTime = endTime;
        }
      }
      // Refund the previous bidder
      _sendValueWithFallbackWithdraw(originalBidder, originalAmount, SEND_VALUE_GAS_LIMIT_SINGLE_RECIPIENT);
    }
    // Withdraw last in order to leverage freed SETH balance.
    if (amount > msg.value) {
      // Withdraw additional ETH required from their available SETH balance.
      unchecked {
        // The if above ensures delta will not underflow.
        // Withdraw ETH from the buyer's account in the SETH token contract.
        seth.marketWithdrawFrom(msg.sender, amount - msg.value);
      }
    }
    emit ReserveAuctionBidPlaced(auctionId, msg.sender, amount, endTime);
  }
  function updateReserveAuction(uint256 auctionId, uint256 reservePrice) external onlyValidAuctionConfig(reservePrice) {
    ReserveAuctionStorage storage auction = auctionIdToAuction[auctionId];
    if (auction.seller != msg.sender) {
      revert NFTMarketReserveAuction_Only_Owner_Can_Update_Auction(auction.seller);
    } else if (auction.endTime != 0) {
      revert NFTMarketReserveAuction_Cannot_Update_Auction_In_Progress();
    } else if (auction.amount == reservePrice) {
      revert NFTMarketReserveAuction_Price_Already_Set();
    }
    // Update the current reserve price.
    auction.amount = reservePrice;
    emit ReserveAuctionUpdated(auctionId, reservePrice);
  }
  function _finalizeReserveAuction(uint256 auctionId, bool keepInEscrow) private {
    ReserveAuctionStorage memory auction = auctionIdToAuction[auctionId];
    if (auction.endTime >= block.timestamp) {
      revert NFTMarketReserveAuction_Cannot_Finalize_Auction_In_Progress(auction.endTime);
    }
    // Remove the auction.
    delete nftContractToTokenIdToAuctionId[auction.nftContract][auction.tokenId];
    delete auctionIdToAuction[auctionId];
    if (!keepInEscrow) {
      // The seller was authorized when the auction was originally created
      super._transferFromEscrow(auction.nftContract, auction.tokenId, auction.bidder, address(0));
    }
    // Distribute revenue for this sale.
    (uint256 protocolFee, uint256 creatorFee, uint256 sellerRev) = _distributeFunds(
      auction.nftContract,
      auction.tokenId,
      auction.seller,
      auction.amount,
      payable(address((uint160(auction.bidReferrerAddressSlot0) << 64) | uint160(auction.bidReferrerAddressSlot1)))
    );
    emit ReserveAuctionFinalized(auctionId, auction.seller, auction.bidder, protocolFee, creatorFee, sellerRev);
  }
  function _transferFromEscrow(
    address nftContract,
    uint256 tokenId,
    address recipient,
    address authorizeSeller
  ) internal virtual override {
    uint256 auctionId = nftContractToTokenIdToAuctionId[nftContract][tokenId];
    if (auctionId != 0) {
      ReserveAuctionStorage storage auction = auctionIdToAuction[auctionId];
      if (auction.endTime == 0) {
        // The auction has not received any bids yet so it may be invalided.
        if (authorizeSeller != address(0) && auction.seller != authorizeSeller) {
          // The account trying to transfer the NFT is not the current owner.
          revert NFTMarketReserveAuction_Not_Matching_Seller(auction.seller);
        }
        // Remove the auction.
        delete nftContractToTokenIdToAuctionId[nftContract][tokenId];
        delete auctionIdToAuction[auctionId];
        emit ReserveAuctionInvalidated(auctionId);
      } else {
        // If the auction has ended, the highest bidder will be the new owner
        // and if the auction is in progress, this will revert.
        // `authorizeSeller != address(0)` does not apply here since an unsettled auction must go
        // through this path to know who the authorized seller should be.
        if (auction.bidder != authorizeSeller) {
          revert NFTMarketReserveAuction_Not_Matching_Seller(auction.bidder);
        }
        // Finalization will revert if the auction has not yet ended.
        _finalizeReserveAuction({ auctionId: auctionId, keepInEscrow: true });
      }
      // The seller authorization has been confirmed.
      authorizeSeller = address(0);
    }
    super._transferFromEscrow(nftContract, tokenId, recipient, authorizeSeller);
  }
  function _transferFromEscrowIfAvailable(
    address nftContract,
    uint256 tokenId,
    address recipient
  ) internal virtual override {
    if (nftContractToTokenIdToAuctionId[nftContract][tokenId] == 0) {
      // No auction was found
      super._transferFromEscrowIfAvailable(nftContract, tokenId, recipient);
    }
  }
  function _transferToEscrow(address nftContract, uint256 tokenId) internal virtual override {
    uint256 auctionId = nftContractToTokenIdToAuctionId[nftContract][tokenId];
    if (auctionId == 0) {
      // NFT is not in auction
      super._transferToEscrow(nftContract, tokenId);
      return;
    }
    // Using storage saves gas since most of the data is not needed
    ReserveAuctionStorage storage auction = auctionIdToAuction[auctionId];
    if (auction.endTime == 0) {
      // Reserve price set, confirm the seller is a match
      if (auction.seller != msg.sender) {
        revert NFTMarketReserveAuction_Not_Matching_Seller(auction.seller);
      }
    } else {
      // Auction in progress, confirm the highest bidder is a match
      if (auction.bidder != msg.sender) {
        revert NFTMarketReserveAuction_Not_Matching_Seller(auction.bidder);
      }
      // Finalize auction but leave NFT in escrow, reverts if the auction has not ended
      _finalizeReserveAuction({ auctionId: auctionId, keepInEscrow: true });
    }
  }
  function getMinBidAmount(uint256 auctionId) external view returns (uint256 minimum) {
    ReserveAuctionStorage storage auction = auctionIdToAuction[auctionId];
    if (auction.endTime == 0) {
      return auction.amount;
    }
    return _getMinIncrement(auction.amount);
  }
  function getReserveAuction(uint256 auctionId) external view returns (ReserveAuction memory auction) {
    ReserveAuctionStorage storage auctionStorage = auctionIdToAuction[auctionId];
    auction = ReserveAuction(
      auctionStorage.nftContract,
      auctionStorage.tokenId,
      auctionStorage.seller,
      DURATION,
      EXTENSION_DURATION,
      auctionStorage.endTime,
      auctionStorage.bidder,
      auctionStorage.amount
    );
  }
  function getReserveAuctionIdFor(address nftContract, uint256 tokenId) external view returns (uint256 auctionId) {
    auctionId = nftContractToTokenIdToAuctionId[nftContract][tokenId];
  }
  function getReserveAuctionBidReferrer(uint256 auctionId) external view returns (address payable referrer) {
    ReserveAuctionStorage storage auction = auctionIdToAuction[auctionId];
    referrer = payable(
      address((uint160(auction.bidReferrerAddressSlot0) << 64) | uint160(auction.bidReferrerAddressSlot1))
    );
  }
  function _getSellerFor(address nftContract, uint256 tokenId)
    internal
    view
    virtual
    override
    returns (address payable seller)
  {
    seller = auctionIdToAuction[nftContractToTokenIdToAuctionId[nftContract][tokenId]].seller;
    if (seller == address(0)) {
      seller = super._getSellerFor(nftContract, tokenId);
    }
  }
  function _isInActiveAuction(address nftContract, uint256 tokenId) internal view override returns (bool) {
    uint256 auctionId = nftContractToTokenIdToAuctionId[nftContract][tokenId];
    return auctionId != 0 && auctionIdToAuction[auctionId].endTime >= block.timestamp;
  }
  uint256[1000] private __gap;
}