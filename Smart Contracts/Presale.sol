// SPDX-License-Identifier: MIT
pragma solidity ^ 0.8.0;
import "Context.sol";
import "Ownable.sol";
import "Address.sol";
import "SafeMath.sol";
import "IBEP20.sol";
import "SafeBEP20.sol";
import "ReentrancyGuard.sol";
import "IUniswapV2Router02.sol";
import "AggregatorV3Interface.sol";
contract RE_PreSale is ReentrancyGuard, Context, Ownable {
    AggregatorV3Interface internal priceFeed;
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;
    uint256 public _rate;
    IBEP20 private _token;
    address private _wallet;
    // Testnet: 0xBA6670261a05b8504E8Ab9c45D97A8eD42573822
    // Mainnet: 0x55d398326f99059fF775485246999027B3197955 (BSC_USD)
    address private usdtAddress = 0xBA6670261a05b8504E8Ab9c45D97A8eD42573822;
    uint256 public softCap;
    uint256 public hardCap;
    uint256 public poolPercent;
    uint256 private _price;
    uint256 private _weiRaised;
    uint256 public endILO;
    uint256 public startILOTimestamp = 0;
    uint public minPurchase;
    uint public maxPurchase;
    uint public availableTokensILO;
    mapping (address => bool) Claimed;
    mapping (address => uint256) CoinPaid;
    mapping (address => uint256) TokenBought;
    mapping (address => uint256) valDrop;
    bool public presaleResult;
    // PancakeSwap(Uniswap) Router and Pair Address
    IUniswapV2Router02 public immutable uniswapV2Router;
    event TokensPurchased(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event DropSent(address[]  receiver, uint256[]  amount);
    event AirdropClaimed(address receiver, uint256 amount);
    event WhitelistSetted(address[] recipient, uint256[] amount);

    event SwapETHForUSDT(uint256 amountIn, address[] path);
    event SwapUSDTForETH(uint256 amount, address[] path);

    constructor (uint256 rate, address wallet, IBE20 token) {

        require(rate > 0, "Pre-Sale: rate is 0");
        require(wallet != address(0), "Pre-Sale: wallet is the zero address");
        require(address(token) != address(0), "Pre-Sale: token is the zero address");
    
        _rate = rate;
        _wallet = wallet;
        _token = token;

        // PancakeSwap Router address:
        // (BSC testnet) 0xD99D1c33F9fC3444f8101754aBC46c52416550D1
        // (BSC mainnet) V2 0x10ED43C718714eb63d5aA57B78B54704E256024E
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
        uniswapV2Router = _uniswapV2Router;
        priceFeed = AggregatorV3Interface(0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526);

    }


    receive() external payable {

        if(endILO > 0 && block.timestamp < endILO){

            buyTokens(_msgSender());
        } else {

            revert('Pre-Sale is closed');
        }
    }

    /**
    * Returns the latest price
    */
    function getLatestPrice() public view returns (int) {
        (
            uint80 roundID, 
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return price;
    }
    
    
    // Swap ETH with USDT(BUSD) token
    function swapETHForUSDT(uint256 amount) private {

        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = usdtAddress;

        // make the swap
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0, // accept any amount of Tokens
            path,
            _wallet, // Wallet address to recieve USDT
            block.timestamp.add(300)
        );

        emit SwapETHForUSDT(amount, path);
    }

    function swapUSDTForETH(uint256 amount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = usdtAddress;
        path[1] = uniswapV2Router.WETH();

        // make the swap
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0, // accept any amount of Tokens
            path,
            _wallet, // Wallet address to recieve USDT
            block.timestamp.add(300)
        );

        emit SwapUSDTForETH(amount, path);
    }

    //Start Pre-Sale
    function startILO(uint endDate, uint _minPurchase, uint _maxPurchase, uint _availableTokens, uint256 _softCap, uint256 _hardCap, uint256 _poolPercent) external onlyOwner ILONotActive() {

        require(endDate > block.timestamp, 'Pre-Sale: duration should be > 0');
        require(_availableTokens > 0 && _availableTokens <= _token.totalSupply(), 'Pre-Sale: availableTokens should be > 0 and <= totalSupply');
        require(_poolPercent >= 0 && _poolPercent < _token.totalSupply(), 'Pre-Sale: poolPercent should be >= 0 and < totalSupply');
        require(_minPurchase > 0, 'Pre-Sale: _minPurchase should > 0');

        startILOTimestamp = block.timestamp;
        endILO = endDate;
        poolPercent = _poolPercent;
        availableTokensILO = _availableTokens.div(_availableTokens.mul(_poolPercent).div(10**2));

        minPurchase = _minPurchase;
        maxPurchase = _maxPurchase;

        softCap = _softCap;
        hardCap = _hardCap;
    }

    function stopILO() external onlyOwner ILOActive() {

        endILO = 0;

        if(_weiRaised > softCap) {

          presaleResult = true;
        } else {

          presaleResult = false;
          _prepareRefund(_wallet);
        }
    }

    function getCurrentTimestamp() public view returns (uint256) {
        return block.timestamp;
    }
    
    function getEndILOTimestamp() public view returns (uint256) {
        require(endILO > 0, "Error: Presale has finished already");
        
        return endILO;
    }
    
    function getStartILOTimestamp() public view returns (uint256) {
        require(startILOTimestamp > 0, "Error: Presale has not started yet");
        
        return startILOTimestamp;
    }

    //Pre-Sale
    function buyTokens(address beneficiary) public nonReentrant ILOActive payable {

        uint256 weiAmount = msg.value;
        _preValidatePurchase(beneficiary, weiAmount);
        uint256 tokens = _getTokenAmount(weiAmount);

        _weiRaised = _weiRaised.add(weiAmount);
        availableTokensILO = availableTokensILO - tokens;

        Claimed[beneficiary] = false;
        CoinPaid[beneficiary] = weiAmount;
        TokenBought[beneficiary] = tokens;

        emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokens);
        _forwardFunds();
    }

    function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal view {

        require(beneficiary != address(0), "Pre-Sale: beneficiary is the zero address");
        require(weiAmount != 0, "Pre-Sale: weiAmount is 0");
        require(weiAmount >= minPurchase, 'have to send at least: minPurchase');
        require(weiAmount <= maxPurchase, 'have to send max: maxPurchase');

        this;
    }

    function claimToken(address beneficiary) public ILONotActive() {

      require(Claimed[beneficiary] == false, "Pre-Sale: You did claim your tokens!");
      Claimed[beneficiary] = true;

      _processPurchase(beneficiary, TokenBought[beneficiary]);
    }

    function claimRefund(address beneficiary) public ILONotActive() {

      if(presaleResult == false) {
          require(Claimed[beneficiary] == false, "Pre-Sale: Only ILO member can refund coins!");
          Claimed[beneficiary] = true;

          payable(beneficiary).transfer(CoinPaid[beneficiary]);
      }
    }

    function _deliverTokens(address beneficiary, uint256 tokenAmount) internal {

        _token.transfer(beneficiary, tokenAmount);
    }


    function _forwardFunds() internal {

        swapETHForUSDT(msg.value);
    }


    function _prepareRefund(address _walletAddress) internal {

        uint256 usdtBalance = IBE20(usdtAddress).balanceOf(_walletAddress);
        swapUSDTForETH(usdtBalance);
    }


    function _processPurchase(address beneficiary, uint256 tokenAmount) internal {

        _deliverTokens(beneficiary, tokenAmount);
    }


    function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {

        return weiAmount.mul(_rate).div(1000000);
    }

    function withdraw() external onlyOwner {

        require(address(this).balance > 0, 'Pre-Sale: Contract has no money');
        payable(_wallet).transfer(address(this).balance);
    }

    function getToken() public view returns (IBE20) {

        return _token;
    }


    function getWallet() public view returns (address) {

        return _wallet;
    }


    function getRate() public view returns (uint256) {

        return _rate;
    }

    function setRate(uint256 newRate) public onlyOwner {

        _rate = newRate;
    }

    function setAvailableTokens(uint256 amount) public onlyOwner {

        availableTokensILO = amount;
    }

    function weiRaised() public view returns (uint256) {

        return _weiRaised;
    }

    modifier ILOActive() {

        require(endILO > 0 && block.timestamp < endILO && availableTokensILO > 0, "Pre-Sale: ILO must be active");
        _;
    }

    modifier ILONotActive() {

        require(endILO < block.timestamp, 'Pre-Sale: ILO should not be active');
        _;
    }
}