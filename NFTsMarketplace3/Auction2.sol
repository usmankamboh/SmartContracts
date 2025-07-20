// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
contract EIP712Base {
    struct EIP712Domain {
        string name;
        string version;
        address verifyingContract;
        bytes32 salt;
    }
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH = keccak256(
        bytes("EIP712Domain(string name,string version,address verifyingContract,bytes32 salt)")
    );
    bytes32 public domainSeparator;
    function _initializeEIP712(string memory name,string memory version) internal{
        domainSeparator = keccak256(
            abi.encode(EIP712_DOMAIN_TYPEHASH,keccak256(bytes(name)),keccak256(bytes(version)),address(this),bytes32(getChainId())));
    }
    function getChainId() public view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }
    function toTypedMessageHash(bytes32 messageHash)internal view returns (bytes32){
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, messageHash));
    }
}
contract NativeMetaTransaction is EIP712Base {
    bytes32 private constant META_TRANSACTION_TYPEHASH = keccak256(bytes("MetaTransaction(uint256 nonce,address from,bytes functionSignature)" ));
    event MetaTransactionExecuted(address userAddress,address relayerAddress, bytes functionSignature);
    mapping(address => uint256) nonces;
    struct MetaTransaction {
        uint256 nonce;
        address from;
        bytes functionSignature;
    }
    function executeMetaTransaction(address userAddress,bytes memory functionSignature,bytes32 sigR,bytes32 sigS,uint8 sigV) public payable returns (bytes memory) {
        MetaTransaction memory metaTx = MetaTransaction({
            nonce: nonces[userAddress],
            from: userAddress,
            functionSignature: functionSignature
        });
        require(verify(userAddress, metaTx, sigR, sigS, sigV),"NMT#executeMetaTransaction: SIGNER_AND_SIGNATURE_DO_NOT_MATCH");
        // increase nonce for user (to avoid re-use)
        nonces[userAddress] = nonces[userAddress] + 1;
        emit MetaTransactionExecuted(userAddress,msg.sender,functionSignature);
        // Append userAddress and relayer address at the end to extract it from calling context
        (bool success, bytes memory returnData) = address(this).call(abi.encodePacked(functionSignature, userAddress));
        require(success, "NMT#executeMetaTransaction: CALL_FAILED");
        return returnData;
    }
    function hashMetaTransaction(MetaTransaction memory metaTx)internal pure returns (bytes32){
        return keccak256(abi.encode(META_TRANSACTION_TYPEHASH,metaTx.nonce,metaTx.from,keccak256(metaTx.functionSignature)));
    }
    function getNonce(address user) public view returns (uint256 nonce) {
        nonce = nonces[user];
    }
    function verify(address signer,MetaTransaction memory metaTx,bytes32 sigR,bytes32 sigS,uint8 sigV) internal view returns (bool) {
        require(signer != address(0), "NMT#verify: INVALID_SIGNER");
        return signer == ecrecover(toTypedMessageHash(hashMetaTransaction(metaTx)),sigV,sigR,sigS);
    }
}
contract ContextMixin {
    function _msgSender()internal view returns (address sender){
        if (msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
                sender := and(mload(add(array, index)),0xffffffffffffffffffffffffffffffffffffffff)
            }
        } else {
            sender = msg.sender;
        }
        return sender;
    }
}
abstract contract Ownable is ContextMixin {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}
abstract contract Pausable is ContextMixin {
    event Paused(address account);
    event Unpaused(address account);
    bool private _paused;
    constructor () {
        _paused = false;
    }
    function paused() public view virtual returns (bool) {
        return _paused;
    }
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}
interface IRoyaltiesManager {
  function getRoyaltiesReceiver(address _contractAddress, uint256 _tokenId) external view returns (address);
}
interface BEP20Interface {
    function balanceOf(address from) external view returns (uint256);
    function transferFrom(address from, address to, uint tokens) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}
interface BEP721Interface {
    function ownerOf(uint256 _tokenId) external view returns (address _owner);
    function transferFrom(address _from, address _to, uint256 _tokenId) external;
    function supportsInterface(bytes4) external view returns (bool);
}

interface BEP721Verifiable is BEP721Interface {
    function verifyFingerprint(uint256, bytes memory) external view returns (bool);
}
contract BEP721BidStorage {
    // 182 days - 26 weeks - 6 months
    uint256 public constant MAX_BID_DURATION = 182 days;
    uint256 public constant MIN_BID_DURATION = 1 minutes;
    uint256 public constant ONE_MILLION = 1000000;
    bytes4 public constant BEP721_Interface = 0x80ac58cd;
    bytes4 public constant BEP721_Received = 0x150b7a02;
    bytes4 public constant BEP721Composable_ValidateFingerprint = 0x8f9f4b63;
    struct Bid {
        // Bid Id
        bytes32 id;
        // Bidder address
        address bidder;
        // BEP721 address
        address tokenAddress;
        // BEP721 token id
        uint256 tokenId;
        // Price for the bid in wei
        uint256 price;
        // Time when this bid ends
        uint256 expiresAt;
        // Fingerprint for composable
        bytes fingerprint;
    }
    // SSS token
    BEP20Interface public SSSToken;
    // Bid by token address => token id => bid index => bid
    mapping(address => mapping(uint256 => mapping(uint256 => Bid))) internal bidsByToken;
    // Bid count by token address => token id => bid counts
    mapping(address => mapping(uint256 => uint256)) public bidCounterByToken;
    // Index of the bid at bidsByToken mapping by bid id => bid index
    mapping(bytes32 => uint256) public bidIndexByBidId;
    // Bid id by token address => token id => bidder address => bidId
    mapping(address => mapping(uint256 => mapping(address => bytes32))) public bidIdByTokenAndBidder;


    address public feesCollector;
    IRoyaltiesManager public royaltiesManager;

    uint256 public feesCollectorCutPerMillion;
    uint256 public royaltiesCutPerMillion;

    // EVENTS
    event BidCreated(
      bytes32 _id,
      address indexed _tokenAddress,
      uint256 indexed _tokenId,
      address indexed _bidder,
      uint256 _price,
      uint256 _expiresAt,
      bytes _fingerprint
    );

    event BidAccepted(
      bytes32 _id,
      address indexed _tokenAddress,
      uint256 indexed _tokenId,
      address _bidder,
      address indexed _seller,
      uint256 _price,
      uint256 _fee
    );

    event BidCancelled(
      bytes32 _id,
      address indexed _tokenAddress,
      uint256 indexed _tokenId,
      address indexed _bidder
    );

    event ChangedFeesCollectorCutPerMillion(uint256 _feesCollectorCutPerMillion);
    event ChangedRoyaltiesCutPerMillion(uint256 _royaltiesCutPerMillion);
    event FeesCollectorSet(address indexed _oldFeesCollector, address indexed _newFeesCollector);
    event RoyaltiesManagerSet(IRoyaltiesManager indexed _oldRoyaltiesManager, IRoyaltiesManager indexed _newRoyaltiesManager);
}
library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount,"Address: insufficient balance");
        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{value: amount}("");
        require(success,"Address: unable to send value, recipient may have reverted");
    }
    function functionCall(address target, bytes memory data)internal returns (bytes memory){
        return functionCall(target, data, "Address: low-level call failed");
    }
    function functionCall(address target,bytes memory data,string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }
    function functionCallWithValue(address target,bytes memory data,uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target,data,value,"Address: low-level call with value failed");
    }
    function functionCallWithValue(address target,bytes memory data,uint256 value,string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value,"Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }
    function functionStaticCall(address target, bytes memory data)internal view returns (bytes memory){
        return functionStaticCall(target,data,"Address: low-level static call failed");
    }
    function functionStaticCall(address target,bytes memory data,string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }
    function functionDelegateCall(address target, bytes memory data)internal returns (bytes memory){
        return functionDelegateCall(target,data,"Address: low-level delegate call failed");
    }
    function functionDelegateCall(address target,bytes memory data,string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }
    function _verifyCallResult(bool success,bytes memory returndata,string memory errorMessage) private pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}
contract BEP721Bid is Ownable, Pausable, BEP721BidStorage, NativeMetaTransaction {
    using Address for address;
    constructor(address _owner,address _feesCollector,address _SSSToken,IRoyaltiesManager _royaltiesManager,uint256 _feesCollectorCutPerMillion,uint256 _royaltiesCutPerMillion) Pausable() {
         // EIP712 init
        _initializeEIP712("SSS", "3.1");
        // Address init
        setFeesCollector(_feesCollector);
        setRoyaltiesManager(_royaltiesManager);
        // Fee init
        setFeesCollectorCutPerMillion(_feesCollectorCutPerMillion);
        setRoyaltiesCutPerMillion(_royaltiesCutPerMillion);
        SSSToken = BEP20Interface(_SSSToken);
        // Set owner
        transferOwnership(_owner);
    }
    function placeBid(address _tokenAddress,uint256 _tokenId,uint256 _price,uint256 _duration)public{
        _placeBid(_tokenAddress,_tokenId,_price,_duration,"");
    }
    function placeBid(address _tokenAddress,uint256 _tokenId,uint256 _price,uint256 _duration,bytes memory _fingerprint)public{
        _placeBid(_tokenAddress,_tokenId,_price,_duration,_fingerprint);
    }
    function _placeBid(address _tokenAddress,uint256 _tokenId,uint256 _price,uint256 _duration,bytes memory _fingerprint)private whenNotPaused(){
        _requireBEP721(_tokenAddress);
        _requireComposableBEP721(_tokenAddress, _tokenId, _fingerprint);
        address sender = _msgSender();
        require(_price > 0, "BEP721Bid#_placeBid: PRICE_MUST_BE_GT_0");
        _requireBidderBalance(sender, _price);
        require(_duration >= MIN_BID_DURATION,"BEP721Bid#_placeBid: DURATION_MUST_BE_GTE_MIN_BID_DURATION");
        require(_duration <= MAX_BID_DURATION,"BEP721Bid#_placeBid: DURATION_MUST_BE_LTE_MAX_BID_DURATION");
        BEP721Interface token = BEP721Interface(_tokenAddress);
        address tokenOwner = token.ownerOf(_tokenId);
        require(tokenOwner != address(0) && tokenOwner != sender,"BEP721Bid#_placeBid: ALREADY_OWNED_TOKEN");
        uint256 expiresAt = block.timestamp + _duration;
        bytes32 bidId = keccak256(abi.encodePacked(block.timestamp,sender,_tokenAddress,_tokenId,_price,_duration,_fingerprint));
        uint256 bidIndex;
        if (_bidderHasABid(_tokenAddress, _tokenId, sender)) {
            bytes32 oldBidId;
            (bidIndex, oldBidId,,,) = getBidByBidder(_tokenAddress, _tokenId, sender);

            // Delete old bid reference
            delete bidIndexByBidId[oldBidId];
        } else {
            // Use the bid counter to assign the index if there is not an active bid.
            bidIndex = bidCounterByToken[_tokenAddress][_tokenId];
            // Increase bid counter
            bidCounterByToken[_tokenAddress][_tokenId]++;
        }
        // Set bid references
        bidIdByTokenAndBidder[_tokenAddress][_tokenId][sender] = bidId;
        bidIndexByBidId[bidId] = bidIndex;
        // Save Bid
        bidsByToken[_tokenAddress][_tokenId][bidIndex] = Bid({
            id: bidId,
            bidder: sender,
            tokenAddress: _tokenAddress,
            tokenId: _tokenId,
            price: _price,
            expiresAt: expiresAt,
            fingerprint: _fingerprint
        });
        emit BidCreated(bidId,_tokenAddress,_tokenId,sender,_price,expiresAt,_fingerprint);
    }
    function onBEP721Received(address _from,address /*_to*/,uint256 _tokenId, bytes memory _data)public whenNotPaused() returns (bytes4){
        bytes32 bidId = _bytesToBytes32(_data);
        uint256 bidIndex = bidIndexByBidId[bidId];
        Bid memory bid = _getBid(msg.sender, _tokenId, bidIndex);
        // Check if the bid is valid.
        require(
            // solium-disable-next-line operator-whitespace
            bid.id == bidId && bid.expiresAt >= block.timestamp,"BEP721Bid#onBEP721Received: INVALID_BID");
        address bidder = bid.bidder;
        uint256 price = bid.price;
        // Check fingerprint if necessary
        _requireComposableBEP721(msg.sender, _tokenId, bid.fingerprint);
        // Check if bidder has funds
        _requireBidderBalance(bidder, price);
        // Delete bid references from contract storage
        delete bidsByToken[msg.sender][_tokenId][bidIndex];
        delete bidIndexByBidId[bidId];
        delete bidIdByTokenAndBidder[msg.sender][_tokenId][bidder];
        // Reset bid counter to invalidate other bids placed for the token
        delete bidCounterByToken[msg.sender][_tokenId];
        // Transfer token to bidder
        BEP721Interface(msg.sender).transferFrom(address(this), bidder, _tokenId);
        uint256 feesCollectorShareAmount;
        uint256 royaltiesShareAmount;
        address royaltiesReceiver;
        // Royalties share
        if (royaltiesCutPerMillion > 0) {
            royaltiesShareAmount = (price * royaltiesCutPerMillion) / ONE_MILLION;
            (bool success, bytes memory res) = address(royaltiesManager).staticcall(
                abi.encodeWithSelector(royaltiesManager.getRoyaltiesReceiver.selector,msg.sender,_tokenId));
            if (success) {
                (royaltiesReceiver) = abi.decode(res, (address));
                if (royaltiesReceiver != address(0)) {
                require(SSSToken.transferFrom(bidder, royaltiesReceiver, royaltiesShareAmount),"BEP721Bid#onBEP721Received: TRANSFER_FEES_TO_ROYALTIES_RECEIVER_FAILED");
                }
            }
        }
        // Fees collector share
        {
            feesCollectorShareAmount = (price * feesCollectorCutPerMillion) / ONE_MILLION;
            uint256 totalFeeCollectorShareAmount = feesCollectorShareAmount;
            if (royaltiesShareAmount > 0 && royaltiesReceiver == address(0)) {
                totalFeeCollectorShareAmount += royaltiesShareAmount;
            }
            if (totalFeeCollectorShareAmount > 0) {
                require(SSSToken.transferFrom(bidder, feesCollector, totalFeeCollectorShareAmount),"BEP721Bid#onBEP721Received: TRANSFER_FEES_TO_FEES_COLLECTOR_FAILED");
            }
        }
        // Transfer MANA from bidder to seller
        require(SSSToken.transferFrom(bidder, _from, price - royaltiesShareAmount - feesCollectorShareAmount),"BEP721Bid#onBEP721Received:: TRANSFER_AMOUNT_TO_TOKEN_OWNER_FAILED");
        emit BidAccepted(bidId,msg.sender,_tokenId,bidder,_from,price,royaltiesShareAmount + feesCollectorShareAmount);
        return BEP721_Received;
    }
    function removeExpiredBids(address[] memory _tokenAddresses, uint256[] memory _tokenIds, address[] memory _bidders)
    public{
        uint256 loopLength = _tokenAddresses.length;
        require(loopLength == _tokenIds.length && loopLength == _bidders.length ,"BEP721Bid#removeExpiredBids: LENGHT_MISMATCH");
        for (uint256 i = 0; i < loopLength; i++) {
            _removeExpiredBid(_tokenAddresses[i], _tokenIds[i], _bidders[i]);
        }
    }
    function _removeExpiredBid(address _tokenAddress, uint256 _tokenId, address _bidder)internal{
        (uint256 bidIndex, bytes32 bidId,,,uint256 expiresAt) = getBidByBidder(_tokenAddress,_tokenId,_bidder);
        require(expiresAt < block.timestamp, "BEP721Bid#_removeExpiredBid: BID_NOT_EXPIRED");
        _cancelBid(bidIndex,bidId,_tokenAddress,_tokenId,_bidder);
    }
    function cancelBid(address _tokenAddress, uint256 _tokenId) public whenNotPaused() {
        address sender = _msgSender();
        // Get active bid
        (uint256 bidIndex, bytes32 bidId,,,) = getBidByBidder(_tokenAddress,_tokenId,sender);
        _cancelBid(bidIndex,bidId,_tokenAddress,_tokenId,sender);
    }
    function _cancelBid(uint256 _bidIndex,bytes32 _bidId,address _tokenAddress,uint256 _tokenId,address _bidder)internal{
        // Delete bid references
        delete bidIndexByBidId[_bidId];
        delete bidIdByTokenAndBidder[_tokenAddress][_tokenId][_bidder];
        // Check if the bid is at the end of the mapping
        uint256 lastBidIndex = bidCounterByToken[_tokenAddress][_tokenId] - 1;
        if (lastBidIndex != _bidIndex) {
            // Move last bid to the removed place
            Bid storage lastBid = bidsByToken[_tokenAddress][_tokenId][lastBidIndex];
            bidsByToken[_tokenAddress][_tokenId][_bidIndex] = lastBid;
            bidIndexByBidId[lastBid.id] = _bidIndex;
        }
        // Delete empty index
        delete bidsByToken[_tokenAddress][_tokenId][lastBidIndex];
        // Decrease bids counter
        bidCounterByToken[_tokenAddress][_tokenId]--;
        // emit BidCancelled event
        emit BidCancelled(_bidId,_tokenAddress,_tokenId,_bidder);
    }
    function _bidderHasABid(address _tokenAddress, uint256 _tokenId, address _bidder)internal view returns (bool){
        bytes32 bidId = bidIdByTokenAndBidder[_tokenAddress][_tokenId][_bidder];
        uint256 bidIndex = bidIndexByBidId[bidId];
        // Bid index should be inside bounds
        if (bidIndex < bidCounterByToken[_tokenAddress][_tokenId]) {
            Bid memory bid = bidsByToken[_tokenAddress][_tokenId][bidIndex];
            return bid.bidder == _bidder;
        }
        return false;
    }
    function getBidByBidder(address _tokenAddress, uint256 _tokenId, address _bidder)public view
        returns (uint256 bidIndex,bytes32 bidId,address bidder,uint256 price,uint256 expiresAt){
        bidId = bidIdByTokenAndBidder[_tokenAddress][_tokenId][_bidder];
        bidIndex = bidIndexByBidId[bidId];
        (bidId, bidder, price, expiresAt) = getBidByToken(_tokenAddress, _tokenId, bidIndex);
        if (_bidder != bidder) {
            revert("BEP721Bid#getBidByBidder: BIDDER_HAS_NOT_ACTIVE_BIDS_FOR_TOKEN");
        }
    }
    function getBidByToken(address _tokenAddress, uint256 _tokenId, uint256 _index)public view returns (bytes32, address, uint256, uint256){
        Bid memory bid = _getBid(_tokenAddress, _tokenId, _index);
        return (bid.id,bid.bidder,bid.price,bid.expiresAt);
    }
    function _getBid(address _tokenAddress, uint256 _tokenId, uint256 _index)internal view returns (Bid memory){
        require(_index < bidCounterByToken[_tokenAddress][_tokenId], "BEP721Bid#_getBid: INVALID_INDEX");
        return bidsByToken[_tokenAddress][_tokenId][_index];
    }
    function setFeesCollectorCutPerMillion(uint256 _feesCollectorCutPerMillion) public onlyOwner {
        feesCollectorCutPerMillion = _feesCollectorCutPerMillion;
        require(feesCollectorCutPerMillion + royaltiesCutPerMillion < 1000000,"BEP721Bid#setFeesCollectorCutPerMillion: TOTAL_FEES_MUST_BE_BETWEEN_0_AND_999999");
        emit ChangedFeesCollectorCutPerMillion(feesCollectorCutPerMillion);
    }
    function setRoyaltiesCutPerMillion(uint256 _royaltiesCutPerMillion) public onlyOwner {
        royaltiesCutPerMillion = _royaltiesCutPerMillion;
        require(feesCollectorCutPerMillion + royaltiesCutPerMillion < 1000000,"BEP721Bid#setRoyaltiesCutPerMillion: TOTAL_FEES_MUST_BE_BETWEEN_0_AND_999999");
        emit ChangedRoyaltiesCutPerMillion(royaltiesCutPerMillion);
    }
    function setFeesCollector(address _newFeesCollector) onlyOwner public {
        require(_newFeesCollector != address(0), "BEP721Bid#setFeesCollector: INVALID_FEES_COLLECTOR");
        emit FeesCollectorSet(feesCollector, _newFeesCollector);
        feesCollector = _newFeesCollector;
    }
    function setRoyaltiesManager(IRoyaltiesManager _newRoyaltiesManager) onlyOwner public {
        require(address(_newRoyaltiesManager).isContract(), "BEP721Bid#setRoyaltiesManager: INVALID_ROYALTIES_MANAGER");
        emit RoyaltiesManagerSet(royaltiesManager, _newRoyaltiesManager);
        royaltiesManager = _newRoyaltiesManager;
    }
    function pause() external onlyOwner {
        _pause();
    }
    function _bytesToBytes32(bytes memory _data) internal pure returns (bytes32) {
        require(_data.length == 32, "BEP721Bid#_bytesToBytes32: DATA_LENGHT_SHOULD_BE_32");
        bytes32 bidId;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            bidId := mload(add(_data, 0x20))
        }
        return bidId;
    }
    function _requireBEP721(address _tokenAddress) internal view {
        require(_tokenAddress.isContract(), "BEP721Bid#_requireBEP721: ADDRESS_NOT_A_CONTRACT");
        BEP721Interface token = BEP721Interface(_tokenAddress);
        require(token.supportsInterface(BEP721_Interface),"BEP721Bid#_requireBEP721: INVALID_CONTRACT_IMPLEMENTATION");
    }
    function _requireComposableBEP721(address _tokenAddress,uint256 _tokenId,bytes memory _fingerprint)internal view{
        BEP721Verifiable composableToken = BEP721Verifiable(_tokenAddress);
        if (composableToken.supportsInterface(BEP721Composable_ValidateFingerprint)) {
            require(composableToken.verifyFingerprint(_tokenId, _fingerprint),"BEP721Bid#_requireComposableBEP721: INVALID_FINGERPRINT");
        }
    }
    function _requireBidderBalance(address _bidder, uint256 _amount) internal view {
        require(SSSToken.balanceOf(_bidder) >= _amount,"BEP721Bid#_requireBidderBalance: INSUFFICIENT_FUNDS");
        require(SSSToken.allowance(_bidder, address(this)) >= _amount,"BEP721Bid#_requireBidderBalance: CONTRACT_NOT_AUTHORIZED");
    }
}