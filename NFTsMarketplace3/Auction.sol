
//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
pragma abicoder v2;
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }
    function _msgData() internal view virtual returns (bytes memory) {
        this;
        return msg.data;
    }
}
interface IBEP165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
interface IBEP721 is IBEP165 {
    event Transfer(address indexed from,address indexed to,uint256 indexed tokenId);
    event Approval(address indexed owner,address indexed approved,uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner,address indexed operator,bool approved);
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(address from,address to,uint256 tokenId) external;
    function transferFrom(address from,address to,uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId)external view returns (address operator);
    function setApprovalForAll(address operator, bool _approved) external;
    function isApprovedForAll(address owner, address operator)external view returns (bool);
    function safeTransferFrom(address from,address to,uint256 tokenId,bytes calldata data) external;
}
interface IBEP721Metadata is IBEP721 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
interface IBEP721Enumerable is IBEP721 {
    function totalSupply() external view returns (uint256);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);
    function tokenByIndex(uint256 index) external view returns (uint256);
}
interface IBEP721Receiver {
    function onBEP721Received(address operator,address from,uint256 tokenId,bytes calldata data) external returns (bytes4);
}
abstract contract BEP165 is IBEP165 {
    bytes4 private constant _INTERFACE_ID_BEP165 = 0x01ffc9a7;
    mapping(bytes4 => bool) private _supportedInterfaces;
    constructor() {
      _registerInterface(_INTERFACE_ID_BEP165);
    }
    function supportsInterface(bytes4 interfaceId)public view virtual override returns (bool){
        return _supportedInterfaces[interfaceId];
    }
    function _registerInterface(bytes4 interfaceId) internal virtual {
        require(interfaceId != 0xffffffff, "BEP165: invalid interface id");
        _supportedInterfaces[interfaceId] = true;
    }
}
library SafeMath {
    function tryAdd(uint256 a, uint256 b)internal pure returns (bool, uint256){
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }
    function trySub(uint256 a, uint256 b)internal pure returns (bool, uint256){
        if (b > a) return (false, 0);
        return (true, a - b);
    }
    function tryMul(uint256 a, uint256 b)internal pure returns (bool, uint256){
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256){
        if (b == 0) return (false, 0);
        return (true, a / b);
    }
    function tryMod(uint256 a, uint256 b)internal pure returns (bool, uint256){
        if (b == 0) return (false, 0);
        return (true, a % b);
    }
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }
    function sub(uint256 a,uint256 b,string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }
    function div(uint256 a,uint256 b,string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }
    function mod(uint256 a,uint256 b,string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}
contract Auction {
    using SafeMath for uint256;
    uint256 public endTime; // Timestamp of the end of the auction (in seconds)
    uint256 public startTime; // The block timestamp which marks the start of the auction
    uint public maxBid; // The maximum bid
    address payable public maxBidder; // The address of the maximum bidder
    address payable public creator; // The address of the auction creator
    Bid[] public bids; // The bids made by the bidders
    uint public tokenId; // The id of the token
    bool public isCancelled; // If the the auction is cancelled
    bool public isDirectBuy; // True if the auction ended due to direct buy
    uint public minIncrement; // The minimum increment for the bid
    uint public directBuyPrice; // The price for a direct buy
    uint public startPrice; // The starting price for the auction
    address public nftAddress;  // The address of the NFT contract
    IBEP721 _nft; // The NFT token
    enum AuctionState { 
        OPEN,
        CANCELLED,
        ENDED,
        DIRECT_BUY
    }
    struct Bid { // A bid on an auction
        address sender;
        uint256 bid;
    }
    // Auction constructor
    constructor(address payable _creator,uint _endTime,uint _minIncrement,uint _directBuyPrice, uint _startPrice,address _nftAddress,uint _tokenId){
        creator = _creator; // The address of the auction creator
        endTime = block.timestamp +  _endTime; // The timestamp which marks the end of the auction (now + 30 days = 30 days from now)
        startTime = block.timestamp; // The timestamp which marks the start of the auction
        minIncrement = _minIncrement; // The minimum increment for the bid
        directBuyPrice = _directBuyPrice; // The price for a direct buy
        startPrice = _startPrice; // The starting price for the auction
        _nft = IBEP721(_nftAddress); // The address of the nft token
        nftAddress = _nftAddress;
        tokenId = _tokenId; // The id of the token
        maxBidder = _creator; // Setting the maxBidder to auction creator.
    }

    // Returns a list of all bids and addresses
    function allBids()
        external
        view
        returns (address[] memory, uint256[] memory)
    {
        address[] memory addrs = new address[](bids.length);
        uint256[] memory bidPrice = new uint256[](bids.length);
        for (uint256 i = 0; i < bids.length; i++) {
            addrs[i] = bids[i].sender;
            bidPrice[i] = bids[i].bid;
        }
        return (addrs, bidPrice);
    }


    // Place a bid on the auction
    function placeBid() payable external returns(bool){
        require(msg.sender != creator); // The auction creator can not place a bid
        require(getAuctionState() == AuctionState.OPEN); // The auction must be open
        require(msg.value > startPrice); // The bid must be higher than the starting price
        require(msg.value > maxBid + minIncrement); // The bid must be higher than the current bid + the minimum increment

        address payable lastHightestBidder = maxBidder; // The address of the last highest bidder
        uint256 lastHighestBid = maxBid; // The last highest bid
        maxBid = msg.value; // The new highest bid
        maxBidder = payable(msg.sender); // The address of the new highest bidder
        if(msg.value >= directBuyPrice){ // If the bid is higher than the direct buy price
            isDirectBuy = true; // The auction has ended
        }
        bids.push(Bid(msg.sender,msg.value)); // Add the new bid to the list of bids

        if(lastHighestBid != 0){ // if there is a bid
            lastHightestBidder.transfer(lastHighestBid); // refund the previous bid to the previous highest bidder
        }
    
        emit NewBid(msg.sender,msg.value); // emit a new bid event
        
        return true; // The bid was placed successfully
    }

    // Withdraw the token after the auction is over
    function withdrawToken() external returns(bool){
        require(getAuctionState() == AuctionState.ENDED || getAuctionState() == AuctionState.DIRECT_BUY); // The auction must be ended by either a direct buy or timeout
        require(msg.sender == maxBidder); // The highest bidder can only withdraw the token
        _nft.transferFrom(address(this), maxBidder, tokenId); // Transfer the token to the highest bidder
        emit WithdrawToken(maxBidder); // Emit a withdraw token event
    }

    // Withdraw the funds after the auction is over
    function withdrawFunds() external returns(bool){ 
        require(getAuctionState() == AuctionState.ENDED || getAuctionState() == AuctionState.DIRECT_BUY); // The auction must be ended by either a direct buy or timeout
        require(msg.sender == creator); // The auction creator can only withdraw the funds
        creator.transfer(maxBid); // Transfers funds to the creator
        emit WithdrawFunds(msg.sender,maxBid); // Emit a withdraw funds event
    } 

    function cancelAuction() external returns(bool){ // Cancel the auction
        require(msg.sender == creator); // Only the auction creator can cancel the auction
        require(getAuctionState() == AuctionState.OPEN); // The auction must be open
        require(maxBid == 0); // The auction must not be cancelled if there is a bid
        isCancelled = true; // The auction has been cancelled
        _nft.transferFrom(address(this), creator, tokenId); // Transfer the NFT token to the auction creator
        emit AuctionCanceled(); // Emit Auction Canceled event
        return true;
    } 
    // Get the auction state
    function getAuctionState() public view returns(AuctionState) {
        if(isCancelled) return AuctionState.CANCELLED; // If the auction is cancelled return CANCELLED
        if(isDirectBuy) return AuctionState.DIRECT_BUY; // If the auction is ended by a direct buy return DIRECT_BUY
        if(block.timestamp >= endTime) return AuctionState.ENDED; // The auction is over if the block timestamp is greater than the end timestamp, return ENDED
        return AuctionState.OPEN; // Otherwise return OPEN
    } 
    event NewBid(address bidder, uint bid); // A new bid was placed
    event WithdrawToken(address withdrawer); // The auction winner withdrawed the token
    event WithdrawFunds(address withdrawer, uint256 amount); // The auction owner withdrawed the funds
    event AuctionCanceled(); // The auction was cancelled
}