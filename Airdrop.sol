// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
contract Context {
    function _msgSender() internal view returns (address payable) {
        return payable(msg.sender);
    }
    function _msgData() internal view returns (bytes memory) {
        address(this);
        return msg.data;
    }
}
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a,uint256 b,string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a,uint256 b,string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }
    function mod(uint256 a,uint256 b,string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}
contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner,address indexed newOwner);
    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }
    function owner() public view returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0),"Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
       _owner = newOwner;
    }
}
interface Token{
    function transfer(address _to, uint256 _value) external  returns (bool);
  function balanceOf(address _owner) external view returns (uint256 balance);
  function transferFrom(address from,address _to, uint256 _value) external  returns (bool);
}
contract Airdrop is Ownable{
    Token token;
    address payable fee_wallet = payable(0x8af1C6990Cec13D60A529a92950EC5AEeBb10dfc);
    uint256 public airdropToken;
    uint256 public per_user = 1000000000000000000000000;  
    uint256 public referral_token = 10000000000000000000000;
    uint256 airdrop_fee = 0.003 ether;  
    address payable public _owner;
    bool airdrop_active = false;    
    mapping(address => bool) public result;
    mapping (address => address)  public referrals;
    mapping(address => mapping(address => uint256)) public airdrop_detail;
    modifier owneronly() {
        require(msg.sender == _owner , "you are not owner");
        _;
    }     
    constructor(){
        _owner = payable(msg.sender);
    }
    function initialize(Token _token,uint256 _airdrop_amount) public {
        token = _token;
        airdropToken = _airdrop_amount ;
        airdrop_active = true; 
        token.transferFrom(msg.sender, address(this),airdropToken); 
    }
    function claimToken(address referral_address) public payable{
       require(msg.value == airdrop_fee, "user must have to pay  0.0003 BNB");
       require(payable(msg.sender) != _owner, "owner can not claim tokens");
       require(airdrop_active == true, " airdrop should be active");            
       require(token.balanceOf(address(this)) >= per_user,"balance must be greater than require amount");
       require(referrals[msg.sender] != referral_address,"user already has used this referral");
       fee_wallet.transfer(airdrop_fee);
       token.transferFrom(address(this),msg.sender,per_user);
       if (referral_token != 0){
           token.transferFrom(address(this),referral_address,referral_token);
       }else {
           token.transferFrom(address(this),address(this),referral_token);
       }
       result[msg.sender] = true; 
       referrals[msg.sender]  =  referral_address ;  
       airdrop_detail[msg.sender][referral_address] = per_user;        
    }
    function cancel() external  owneronly{        
        airdrop_active = false;
    }
    function change_TokenAdress(Token newTokenAdres) public owneronly {
        token = newTokenAdres;
    }    
    function chnage_tokensPerUser(uint256 newPerUser) public owneronly {
        per_user = newPerUser;
    } 
    function add_airdropToken(uint256 _airdrop_amount) public owneronly{
        token.transferFrom(msg.sender, address(this),_airdrop_amount); 
        airdropToken = airdropToken + _airdrop_amount;
    }
    function change_referral_token(uint256 _referral_token) public owneronly {
        referral_token = _referral_token ;
    }
    function change_fee_wallet(address payable _fee_wallet) public owneronly {
        fee_wallet = _fee_wallet;
    }
    function change_airdrop_fee(uint256 _airdrop_fee) public owneronly{
        airdrop_fee = _airdrop_fee;
    }
    function referral_view(address _airdroper) public view {
        referrals[_airdroper];
    }
    function airdropdetail(address _user) public view {
        airdrop_detail[_user];
    }
}