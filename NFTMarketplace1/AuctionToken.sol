// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;
import "./BEP20.sol";
import "./NFTCollection.sol";
contract Marketplace is IBEP721Receiver {
    // Name of the marketplace
    string public name;
    // Index of auctions
    uint256 public index = 0;
    // Structure to define auction properties
    struct Auction {
        uint256 index; // Auction Index
        address addressNFTCollection; // Address of the BEP721 NFT Collection contract
        address addressPaymentToken; // Address of the BEP20 Payment Token contract
        uint256 nftId; // NFT Id
        address creator; // Creator of the Auction
        address payable currentBidder; // Address of the current bider
        address payable highestBidder; // Address of the highest bider
        uint256 currentBid; // Current bid for the auction
        uint256 highestBid; // highest bid for the auction
        uint256 endAuction; // Timestamp for the end day&time of the auction
        uint256 startAuction; // Timestamp for the start day&time of the auction
        uint256 bidCount; // Number of bid placed on the auction
    }
    // Array will all auctions
    Auction[] private allAuctions;
    // Public event to notify that a new auction has been created
    event NewAuction(
        uint256 index,
        address addressNFTCollection,
        address addressPaymentToken,
        uint256 nftId,
        address mintedBy,
        address currentBidder,
        uint256 currentBid,
        uint256 startAuction,
        uint256 endAuction,
        uint256 bidCount
    );
    // Public event to notify that a new bid has been placed
    event NewBidOnAuction(uint256 auctionIndex, uint256 newBid);
    // Public event to notif that winner of an
    // auction claim for his reward
    event NFTClaimed(uint256 auctionIndex, uint256 nftId, address claimedBy);
    // Public event to notify that the creator of
    // an auction claimed for his money
    event TokensClaimed(uint256 auctionIndex, uint256 nftId, address claimedBy);
    // Public event to notify that an NFT has been refunded to the
    // creator of an auction
    event NFTRefunded(uint256 auctionIndex, uint256 nftId, address claimedBy);
    // constructor of the contract
    constructor(string memory _name) {
        name = _name;
    }
    function isContract(address _addr) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
    function createAuction(address _addressNFTCollection,address _addressPaymentToken,uint256 _nftId,uint256 _initialBid,uint256 _endAuction,uint256 _startAuction) external returns (uint256) {
        //Check is addresses are valid
        require(isContract(_addressNFTCollection),"Invalid NFT Collection contract address");
        require(isContract(_addressPaymentToken),"Invalid Payment Token contract address");
        // Check if the endAuction time is valid
        require(_endAuction > block.timestamp, "Invalid end date for auction");
        // Check if the initial bid price is > 0
        require(_initialBid > 0, "Invalid initial bid price");
        // Get NFT collection contract
        NFTCollection nftCollection = NFTCollection(_addressNFTCollection);
        // Make sure the sender that wants to create a new auction
        // for a specific NFT is the owner of this NFT
        require(nftCollection.ownerOf(_nftId) == msg.sender,"Caller is not the owner of the NFT");
        // Make sure the owner of the NFT approved that the MarketPlace contract
        // is allowed to change ownership of the NFT
        require(nftCollection.getApproved(_nftId) == address(this),"Require NFT ownership transfer approval");
        // Lock NFT in Marketplace contract
        require(nftCollection.transferNFTFrom(msg.sender, address(this), _nftId));
        //Casting from address to address payable
        address payable currentBidder = payable(address(0));
        address payable highestBidder = payable(address(0));
        // Create new Auction object
        Auction memory newAuction = Auction({
            index: index,
            addressNFTCollection: _addressNFTCollection,
            addressPaymentToken: _addressPaymentToken,
            nftId: _nftId,
            creator: msg.sender,
            currentBidder: currentBidder,
            highestBidder: highestBidder,
            currentBid: _initialBid,
            highestBid: _initialBid,
            endAuction: _endAuction,
            startAuction: _startAuction,
            bidCount: 0
        });
        //update list
        allAuctions.push(newAuction);
        // increment auction sequence
        index++;
        // Trigger event and return index of new auction
        emit NewAuction(
            index,
            _addressNFTCollection,
            _addressPaymentToken,
            _nftId,
            msg.sender,
            currentBidder,
            _initialBid,
            _endAuction,
            _startAuction,
            0
        );
        return index;
    }
    function isOpen(uint256 _auctionIndex) public view returns (bool) {
        Auction storage auction = allAuctions[_auctionIndex];
        if (auction.startAuction > auction.endAuction) return false;
        return true;
    }
    function getHigestBidder(uint256 _auctionIndex)public view returns (address){
        require(_auctionIndex < allAuctions.length, "Invalid auction index");
        return allAuctions[_auctionIndex].highestBidder;
    }
    function getHighestBid(uint256 _auctionIndex)public view returns (uint256){
        require(_auctionIndex < allAuctions.length, "Invalid auction index");
        return allAuctions[_auctionIndex].highestBid;
    }
    function bid(uint256 _auctionIndex, uint256 _newBid,BEP20 _addressPaymentToken)external returns (bool){
        require(_auctionIndex < allAuctions.length, "Invalid auction index");
        Auction storage auction = allAuctions[_auctionIndex];
        // check if auction is still open
        require(isOpen(_auctionIndex), "Auction is not open");
        // check if new bid price is higher than the current one
        require(_newBid > auction.highestBid,"New bid price must be higher than the highest bid");
        // check if new bider is not the owner
        require(msg.sender != auction.creator,"Creator of the auction cannot place new bid");
        // get BEP20 token contract
        _addressPaymentToken = BEP20(auction.addressPaymentToken);
        // new bid is better than current bid!
        // transfer token from new bider account to the marketplace account to lock the tokens
        require(_addressPaymentToken.transferFrom(msg.sender, address(this), _newBid),"Tranfer of token failed");
        // new bid is valid so must refund the current bid owner (if there is one!)
        if (auction.bidCount > 0) {
            _addressPaymentToken.transfer(auction.currentBidder,auction.currentBid);
        }
        // update auction info
        address payable newBidder = payable(msg.sender);
        auction.highestBidder = newBidder;
        auction.highestBid = _newBid;
        auction.bidCount++;
        // Trigger public event
        emit NewBidOnAuction(_auctionIndex, _newBid);
        return true;
    }
    function claimNFT(uint256 _auctionIndex) external {
        require(_auctionIndex < allAuctions.length, "Invalid auction index");
        // Check if the auction is closed
        require(!isOpen(_auctionIndex), "Auction is still open");
        // Get auction
        Auction storage auction = allAuctions[_auctionIndex];
        // Check if the caller is the winner of the auction
        require(auction.currentBidder == msg.sender,"NFT can be claimed only by the current bid owner");
        // Get NFT collection contract
        NFTCollection nftCollection = NFTCollection(auction.addressNFTCollection);
        // Transfer NFT from marketplace contract to the winner address
        require(nftCollection.transferNFTFrom(address(this),auction.currentBidder,_auctionIndex));
        // Get BEP20 Payment token contract
        BEP20 paymentToken = BEP20(auction.addressPaymentToken);
        // Transfer locked token from the marketplace contract to the auction creator address
        require(paymentToken.transfer(auction.creator, auction.currentBid));
        emit NFTClaimed(_auctionIndex, auction.nftId, msg.sender);
    }
    function claimToken(uint256 _auctionIndex) external {
        require(_auctionIndex < allAuctions.length, "Invalid auction index"); // XXX Optimize
        // Check if the auction is closed
        require(!isOpen(_auctionIndex), "Auction is still open");
        // Get auction
        Auction storage auction = allAuctions[_auctionIndex];
        // Check if the caller is the creator of the auction
        require(auction.creator == msg.sender,"Tokens can be claimed only by the creator of the auction");
        // Get NFT Collection contract
        NFTCollection nftCollection = NFTCollection(auction.addressNFTCollection);
        // Transfer NFT from marketplace contract
        // to the winned of the auction
        nftCollection.transferFrom(address(this),auction.currentBidder,auction.nftId);
        // Get BEP20 Payment token contract
        BEP20 addresspaymentToken = BEP20(auction.addressPaymentToken);
        // Transfer locked tokens from the market place contract
        // to the wallet of the creator of the auction
        addresspaymentToken.transfer(auction.creator, auction.currentBid);
        emit TokensClaimed(_auctionIndex, auction.nftId, msg.sender);
    }
    function refund(uint256 _auctionIndex) external {
        require(_auctionIndex < allAuctions.length, "Invalid auction index");
        // Check if the auction is closed
        require(!isOpen(_auctionIndex), "Auction is still open");
        // Get auction
        Auction storage auction = allAuctions[_auctionIndex];
        // Check if the caller is the creator of the auction
        require(auction.creator == msg.sender,"Tokens can be claimed only by the creator of the auction");
        require(auction.currentBidder == address(0),"Existing bider for this auction");
        // Get NFT Collection contract
        NFTCollection nftCollection = NFTCollection(auction.addressNFTCollection);
        // Transfer NFT back from marketplace contract
        // to the creator of the auction
        nftCollection.transferFrom(address(this),auction.creator,auction.nftId);
        emit NFTRefunded(_auctionIndex, auction.nftId, msg.sender);
    }
    function onBEP721Received(address,address,uint256,bytes memory) public virtual override returns (bytes4) {
        return this.onBEP721Received.selector;
    }
}
