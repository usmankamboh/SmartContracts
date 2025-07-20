// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;
pragma experimental ABIEncoderV2;
interface IAuctionHouse {
    struct Auction {
        // ID for the BEP721 token
        uint256 tokenId;
        // Address for the BEP721 contract
        address tokenContract;
        // Whether or not the auction curator has approved the auction to start
        bool approved;
        // The current highest bid amount
        uint256 amount;
        // The length of time to run the auction for, after the first bid was made
        uint256 duration;
        // The time of the first bid
        uint256 firstBidTime;
        // The minimum price of the first bid
        uint256 reservePrice;
        // The sale percentage to send to the curator
        uint8 curatorFeePercentage;
        // The address that should receive the funds once the NFT is sold.
        address tokenOwner;
        // The address of the current highest bid
        address payable bidder;
        // The address of the auction's curator.
        // The curator can reject or approve an auction
        address payable curator;
        // The address of the ERC-20 currency to run the auction with.
        // If set to 0x0, the auction will be run in BNB
        address auctionCurrency;
    }
    event AuctionCreated(uint256 indexed auctionId,uint256 indexed tokenId,address indexed tokenContract,uint256 duration,
        uint256 reservePrice,address tokenOwner,address curator,uint8 curatorFeePercentage,address auctionCurrency);
    event AuctionApprovalUpdated(uint256 indexed auctionId,uint256 indexed tokenId,address indexed tokenContract,bool approved);
    event AuctionReservePriceUpdated(uint256 indexed auctionId,uint256 indexed tokenId,address indexed tokenContract,uint256 reservePrice);
    event AuctionBid(uint256 indexed auctionId,uint256 indexed tokenId,address indexed tokenContract,address sender,uint256 value,bool firstBid,bool extended);
    event AuctionDurationExtended(uint256 indexed auctionId,uint256 indexed tokenId,address indexed tokenContract,uint256 duration);
    event AuctionEnded(uint256 indexed auctionId,uint256 indexed tokenId,address indexed tokenContract,address tokenOwner,
        address curator,address winner,uint256 amount,uint256 curatorFee,address auctionCurrency);
    event AuctionCanceled(uint256 indexed auctionId,uint256 indexed tokenId,address indexed tokenContract,address tokenOwner);
    function createAuction(uint256 tokenId,address tokenContract,uint256 duration,uint256 reservePrice,
        address payable curator,uint8 curatorFeePercentages,address auctionCurrency) external returns (uint256);
    function setAuctionApproval(uint256 auctionId, bool approved) external;
    function setAuctionReservePrice(uint256 auctionId, uint256 reservePrice) external;
    function createBid(uint256 auctionId, uint256 amount) external payable;
    function endAuction(uint256 auctionId) external;
    function cancelAuction(uint256 auctionId) external;
}
// This contract is meant to mimic a bidding contract that does not implement on IERC721 Received,
// and thus should cause a revert when an auction is finalized with this as the winning bidder.
contract BadBidder {
    address auction;
    address sss;

    constructor(address _auction, address _sss){
        auction = _auction;
        sss = _sss;
    }

    function placeBid(uint256 auctionId, uint256 amount) external payable {
        IAuctionHouse(auction).createBid{value: amount}(auctionId, amount);
    }

    receive() external payable {}
    fallback() external payable {}
}