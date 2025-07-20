//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.14;
interface IBEP721 {
    function transfer(address to, uint amount) external;
    function transferFrom(address from,address to,uint256 tokenId) external;
}
contract Auction {
    event Start();
    event End(address highestBidder, uint highestBid);
    event Bid(address indexed sender, uint amount);
    event Withdraw(address indexed bidder, uint amount);
    address payable public seller;
    uint256 public price;
    bool public started;
    bool public ended;
    uint256 public endAt;
    uint256 public startAt;
    IBEP721 public nft;
    uint256 public nftId;
    uint256 public highestBid;
    address payable public highestBidder;
    mapping(address => address) public bidder;
    mapping(address => uint) public bids;
    address payable owner;
    constructor () {
        owner = payable(msg.sender);
    }
    function startAuction(IBEP721 _nft, uint256 _nftId, uint256 startingBid,uint256 _startAt,uint _endAt,uint256 _price) external {
        require(!started, "Already started!");
        seller = payable(msg.sender);
        nft = _nft;
        nftId = _nftId;
        highestBid = startingBid;
        endAt = _endAt;
        startAt = _startAt;
        price = _price;
        nft.transferFrom(msg.sender, address(this), nftId);
        started = true;
        emit Start();
    }
    function bid() external payable {
        require (msg.sender != seller, "biider should not be seller");
        require(started, "Not started.");
        require(startAt < endAt, "Ended!");
        require(msg.value > highestBid);
        if (highestBidder != address(0)) {
            bids[highestBidder] += highestBid;
        }
        highestBid = msg.value;
        highestBidder = payable(msg.sender);
        emit Bid(highestBidder, highestBid);
    }
    function withdraw() external payable {
        require(msg.sender != highestBidder);
        require (msg.sender != seller);
        uint bal = bids[msg.sender];
        bids[msg.sender] = 0;
        emit Withdraw(msg.sender, bal);
    }
    function end() external {
        require(started, "You need to start first!");
        require(startAt >= endAt, "Auction is still ongoing!");
        require(!ended, "Auction already ended!");
        if (highestBidder != address(0)) {
            nft.transfer(highestBidder, nftId);
        } else {
            nft.transfer(seller, nftId);
        }
        ended = true;
        emit End(highestBidder, highestBid);
    }
}