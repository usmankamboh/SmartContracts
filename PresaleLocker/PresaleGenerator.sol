// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

import "./Presale.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
import "./IBEP20.sol";
import "./TransferHelper.sol";
import "./PresaleHelper.sol";

interface IPresaleFactory {
    function registerPresale (address _presaleAddress) external;
    function presaleIsRegistered(address _presaleAddress) external view returns (bool);
}

interface IUniswapV2Locker {
    function lockLPToken (address _lpToken, uint256 _amount, uint256 _unlock_date, address payable _referral, bool _fee_in_bnb, address payable _withdrawer) external payable;
}

contract PresaleGenerator is Ownable {
    using SafeMath for uint256;
    
    IPresaleFactory public PRESALE_FACTORY;
    IPresaleSettings public PRESALE_SETTINGS;
    
    struct PresaleParams {
        uint256 amount;
        uint256 tokenPrice;
        uint256 maxSpendPerBuyer;
        uint256 hardcap;
        uint256 softcap;
        uint256 liquidityPercent;
        uint256 listingRate; // sale token listing price on uniswap
        uint256 startblock;
        uint256 endblock;
        uint256 lockPeriod;
    }
    
    constructor()  {
        PRESALE_FACTORY = IPresaleFactory(0x8E553c077eA279C4ae6D2912eCE6200b7903a189);
        PRESALE_SETTINGS = IPresaleSettings(0x677d300E2748C463530BAf7810b9B815995D0d9B);
    }
    
    /**
     * @notice Creates a new Presale contract and registers it in the PresaleFactory.sol.
     */
    function createPresale (
      address payable _presaleOwner,
      IBEP20 _presaleToken,
      IBEP20 _Token,
      IBEP20 _baseToken,
      address payable _referralAddress,
      uint256[10] memory uint_params
      ) public payable {
        PresaleParams memory params;
        params.amount = uint_params[0];
        params.tokenPrice = uint_params[1];
        params.maxSpendPerBuyer = uint_params[2];
        params.hardcap = uint_params[3];
        params.softcap = uint_params[4];
        params.liquidityPercent = uint_params[5];
        params.listingRate = uint_params[6];
        params.startblock = uint_params[7];
        params.endblock = uint_params[8];
        params.lockPeriod = uint_params[9];
        if (params.lockPeriod < 4 weeks) {
            params.lockPeriod = 4 weeks;
        } 
        // Charge BNB fee for contract creation
        require(msg.value == PRESALE_SETTINGS.getBnbCreationFee(), 'FEE NOT MET');
        PRESALE_SETTINGS.getBnbAddress().transfer(PRESALE_SETTINGS.getBnbCreationFee());
        
        if (_referralAddress != address(0)) {
            require(PRESALE_SETTINGS.referrerIsValid(_referralAddress), 'INVALID REFERRAL');
        }
        require(params.amount >= 10000, 'MIN DIVIS'); // minimum divisibility
        require(params.endblock.sub(params.startblock) <= PRESALE_SETTINGS.getMaxPresaleLength());
        require(params.tokenPrice.mul(params.hardcap) > 0, 'INVALID PARAMS'); // ensure no overflow for future calculations
        require(params.liquidityPercent >= 300 && params.liquidityPercent <= 1000, 'MIN LIQUIDITY'); // 30% minimum liquidity lock 
        uint256 tokensRequiredForPresale = PresaleHelper.calculateAmountRequired(params.amount, params.tokenPrice, params.listingRate, params.liquidityPercent, PRESALE_SETTINGS.getTokenFee());
        Presale newPresale = new Presale(address(this));
        TransferHelper.safeTransferFrom(address(_presaleToken), address(msg.sender), address(newPresale), tokensRequiredForPresale);
        newPresale.init1(_presaleOwner,_Token, params.amount, params.tokenPrice, params.maxSpendPerBuyer, params.hardcap, params.softcap, 
        params.liquidityPercent, params.listingRate, params.startblock, params.endblock, params.lockPeriod);
       // newPresale.init2(_baseToken, _presaleToken, PRESALE_SETTINGS.getBaseFee(), PRESALE_SETTINGS.getTokenFee(), PRESALE_SETTINGS.getReferralFee(), PRESALE_SETTINGS.getBnbAddress(), PRESALE_SETTINGS.getTokenAddress(), _referralAddress);
        newPresale.init2(_baseToken, _presaleToken, PRESALE_SETTINGS.getBaseFee(), PRESALE_SETTINGS.getTokenFee(), PRESALE_SETTINGS.getReferralFee());
        PRESALE_FACTORY.registerPresale(address(newPresale));
    }
    
}