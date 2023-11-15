// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../library/SafeMath.sol";
import "../library/SafeDecimal.sol";
import "../interfaces/IsVim.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IPriceCalculator.sol";
import "../interfaces/IPancakePair.sol";
import "../interfaces/IBondCalculator.sol";
import "../interfaces/ITreasury.sol";
import "../interfaces/IDiscount.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface ILPBondHelper {
    function getPayout(address _bond, address _token, uint256 _amount) external view returns(uint256);
}

struct Bond {
    uint payout; // Vim remaining to be paid
    uint vesting; // Blocks left to vest
    uint lastTimestamp; // Last interaction
    uint pricePaid; // In USDT, for front end viewing
}

interface IBondDespository {
    function principle() external view returns(address);
    function bondPriceInUSD() external view returns(uint256);
    function bondPriceInUSD(address _user) external view returns(uint256);
    function maxPayout() external view returns (uint256);
    function standardizedDebtRatio() external view returns (uint256);
    function bondInfo(address _depositor) external view returns (Bond memory);
    function pendingPayoutFor(address _depositor) external view returns (uint pendingPayout_);
    function payoutFor(uint _value) external view returns (uint256);
    function payoutFor(uint _value, address _user) external view returns (uint256);
    function isLiquidityBond() external view returns (bool);
    function currentDebt() external view returns ( uint );
    function maxDebt() external view returns ( uint );
}

struct Epoch {
    uint length;
    uint number;
    uint endTimestamp;
    uint distribute;
}

interface IStaking2 {
    function epoch() external view returns(Epoch memory);
}

contract Dashboard is OwnableUpgradeable {
    using SafeMath for uint256;
    using SafeDecimal for uint256;

    address public Vim;
    address public sVim;
    address public staking;
    address public treasury;

    struct Bonds {
        bool enable;
        bool isLP;
        address bond;
        address lpBondHelper; 
    }

    Bonds[] public bonds;

    IPriceCalculator public priceCalculator;
    IBondCalculator public bondCalculator;

    address public presale;
    address public DAO;

    mapping(address => address) public mapBondToLPBondHelper;
    mapping(address => uint256) public mappingRFV;

    address public discount;

    function initialize(
        address _Vim,
        address _sVim,
        address _staking,
        address _treasury,
        address _priceCalculator,
        address _bondCalculator,
        address _dao
    ) external initializer {
        require(_Vim != address(0));
        require(_sVim != address(0));
        require(_staking != address(0));
        require(_treasury != address(0));
        require(_priceCalculator != address(0));
        require(_bondCalculator != address(0));
        require(_dao != address(0));

        __Ownable_init();

        Vim = _Vim;
        sVim = _sVim;
        staking = _staking;
        treasury = _treasury;
        priceCalculator = IPriceCalculator(_priceCalculator);
        bondCalculator = IBondCalculator(_bondCalculator);
        DAO = _dao;
    }

    function bondsLength() external view returns(uint256) {
        return bonds.length;
    }

    function setStaking(address _staking) external onlyOwner {
        require( _staking != address(0) );
        staking = _staking;
    }

    function setTreasury(address _treasury) external onlyOwner {
        require( _treasury != address(0) );
        treasury = _treasury;
    }

    function setPriceCalculator(address _priceCalculator) external onlyOwner {
        require( _priceCalculator != address(0) );
        priceCalculator = IPriceCalculator(_priceCalculator);
    }

    function setBondCalculator(address _bondCalculator) external onlyOwner {
        require(_bondCalculator != address(0));
        bondCalculator = IBondCalculator(_bondCalculator);
    }

    function setBonds(address _bond, bool _enable, bool _isLP, address _lpBondHelper) external onlyOwner {
        require( _bond != address(0) );
        uint256 length = bonds.length;
        for (uint256 i = 0; i < length; ++i) {
            if (bonds[i].bond == _bond) {
                bonds[i].enable = _enable;
                bonds[i].isLP = _isLP;
                bonds[i].lpBondHelper = _lpBondHelper;
                mapBondToLPBondHelper[_bond] = _lpBondHelper;
                return;
            }
        }

        bonds.push( Bonds({
            bond: _bond,
            enable: _enable,
            isLP: _isLP,
            lpBondHelper: _lpBondHelper
        }));
        mapBondToLPBondHelper[_bond] = _lpBondHelper;
    }

    function setPresale(address _presale) external onlyOwner {
        require(_presale != address(0));
        presale = _presale;
    }

    function setDAO(address _dao) external onlyOwner {
        require(_dao != address(0));
        DAO = _dao;
    }

    function setRFV(address _bond, uint256 _minRFV) external onlyOwner {
        mappingRFV[_bond] = _minRFV;
    }

    function setDiscount( address _discount ) external onlyOwner() {
        require(_discount != address(0));
        discount = _discount;
    }

    function priceOfVim() public view returns(uint256) {
        return priceCalculator.priceOfToken(Vim);
    }

    function priceOfToken(address _token) public view returns(uint256) {
        if (_token == sVim) {
            _token = Vim;
        }
        return priceCalculator.priceOfToken(_token);
    }

    function totalSupply() public view returns(uint256) {
        return IERC20(Vim).totalSupply();
    }

    function totalStaking() public view returns(uint256 amount) {
        amount = IsVim(sVim).circulatingSupply();
    }

    function currentIndex() public view returns(uint256) {
        return IsVim(sVim).index();
    }

    struct BondsInfo {
        address bond;
        uint256 mv;
        uint256 rfv;
        uint256 pol;
        uint256 price;
    }

    function bondsInfo() public view returns(BondsInfo[] memory info, uint256 mv, uint256 rfv) {
        Bonds[] memory _bonds = bonds;
        uint256 length = _bonds.length;
        uint256 count = 0;
        for (uint256 i = 0; i < length; ++i) {
            if (_bonds[i].enable == false) {
                continue;
            }
            count++;
        }
        info = new BondsInfo[](count);
        uint256 j = 0;
        for (uint256 i = 0; i < length; ++i) {
            if (_bonds[i].enable == false) {
                continue;
            }

            address bond = _bonds[i].bond;
            address token = IBondDespository(bond).principle();
            uint256 bal = IERC20(token).balanceOf(treasury);
            uint256 value = bal.mul(priceCalculator.priceOfToken(token)).div(1e18);
            uint256 decimals =  IERC20(token).decimals();
            if (decimals < 18) {
                value = value * (10 ** (18 - decimals));
            }
            uint256 minRFV = mappingRFV[bond];
            value = value.max(minRFV);
            info[j].bond = bond;
            info[j].mv = value;
            info[j].price = IBondDespository(bond).bondPriceInUSD();
            if (_bonds[i].isLP) {
                info[j].rfv = bondCalculator.valuation(token, bal);
                uint256 totalAmount = IERC20(token).totalSupply();
                if (totalAmount > 0) {
                    info[j].pol = bal.mul(1e18).div(totalAmount);
                } else {
                    info[j].pol = 0;
                }
            } else {
                info[j].rfv = value;
                info[j].pol = 0;
            }

            mv += info[j].mv;
            rfv += info[j].rfv;
            ++j;
        }
    }

    function getNextReward() public view returns(uint256) {
        return IStaking2(staking).epoch().distribute;
    }

    function vimverseInfo() public view returns(
        uint256 vimPrice, 
        uint256 vimTotalSupply, 
        uint256 index,
        uint256 mv,
        uint256 rfv,
        uint256 vimStaking,
        uint256 vimContractLocked,
        uint256 nextReward,
        BondsInfo[] memory info) 
    {
        vimPrice = priceOfVim();
        vimTotalSupply = totalSupply();
        index = currentIndex();
        (info, mv, rfv) = bondsInfo();
        vimStaking = totalStaking();
        nextReward = getNextReward();

        vimContractLocked = IERC20(Vim).balanceOf(presale);
        vimContractLocked = vimContractLocked.add(IERC20(Vim).balanceOf(DAO));
        Bonds[] memory _bonds = bonds;
        uint256 length = _bonds.length;
        for (uint256 i = 0; i < length; ++i) {
            if (_bonds[i].enable == false) {
                continue;
            }

            address bond = _bonds[i].bond;
            vimContractLocked = vimContractLocked.add(IERC20(Vim).balanceOf(bond));
        }

        vimContractLocked = vimContractLocked;
    }

    function userStakingInfo(address _user) public view returns(
        uint256 balanceOfVim,
        uint256 stakedBalance,
        uint256 nextRewardAmount,
        uint256 nextRewardYield,
        uint256 rebaseLeftTime
    ) {
        balanceOfVim = IERC20(Vim).balanceOf(_user);
        stakedBalance = IERC20(sVim).balanceOf(_user);
        uint256 totalStaked = totalStaking();
        Epoch memory epoch = IStaking2(staking).epoch();
        uint256 totalNextReward = epoch.distribute;
        if (totalStaked > 0) {
            nextRewardAmount = totalNextReward.mul(stakedBalance).div(totalStaked);
            nextRewardYield = totalNextReward.mul(1e9).div(totalStaked);
        } else {
            nextRewardAmount = 0;
            nextRewardYield = 0;
        }

        if (epoch.endTimestamp > block.timestamp) {
            rebaseLeftTime = epoch.endTimestamp.sub(block.timestamp);
        } else {
            rebaseLeftTime = 0;
        }
    }

    function userBondInfo(address _user, address _bond, uint256 _amount) public view returns(
        uint256[] memory info
    ) {
        info = new uint256[](11);
        //bondPrice
        info[0] = IBondDespository(_bond).bondPriceInUSD();

        //vimPrice   
        info[1] = priceOfVim();

        address token = IBondDespository(_bond).principle();
        //balance
        info[2] = IERC20(token).balanceOf(_user); 

        //balanceInUSD  
        info[3] = info[2].mul(priceCalculator.priceOfToken(token)).div(1e18); 

        //maxPayout
        info[4] = IBondDespository(_bond).maxPayout();

        //debtRatio
        info[5] = IBondDespository(_bond).standardizedDebtRatio();
        if (IBondDespository(_bond).isLiquidityBond() == false) {
            info[5] = info[5].mul(1e9);
        }

        //pendingRewards
        uint256 payout = IBondDespository(_bond).bondInfo(_user).payout;
        info[6] = IsVim(sVim).balanceForGons(payout);

        //claimableRewards
        info[7] = IBondDespository(_bond).pendingPayoutFor(_user);

        //payout
        if (_amount == 0) {
            info[8] = 0;
        } else {
            uint256 value = ITreasury(treasury).valueOf(token, _amount);
            info[8] = IBondDespository(_bond).payoutFor(value, _user);
        }

        info[9] = IBondDespository(_bond).currentDebt();
        info[10] = IBondDespository(_bond).maxDebt();
    }

    function userQuickBondInfo(address _user, address _bond, address _token, uint256 _amount) public view returns(
        uint256[] memory info
    ) {
        info = new uint256[](11);
        //bondPrice
        info[0] = IBondDespository(_bond).bondPriceInUSD();

        //vimPrice   
        info[1] = priceOfVim();

        //balance
        info[2] = IERC20(_token).balanceOf(_user); 

        //balanceInUSD  
        info[3] = info[2].mul(priceCalculator.priceOfToken(_token)).div(1e18); 

        //maxPayout
        info[4] = IBondDespository(_bond).maxPayout();

        //debtRatio
        info[5] = IBondDespository(_bond).standardizedDebtRatio();
        if (IBondDespository(_bond).isLiquidityBond() == false) {
            info[5] = info[5].mul(1e9);
        }

        //pendingRewards
        uint256 payout = IBondDespository(_bond).bondInfo(_user).payout;
        info[6] = IsVim(sVim).balanceForGons(payout);

        //claimableRewards
        info[7] = IBondDespository(_bond).pendingPayoutFor(_user);

        //payout
        if (_amount == 0) {
            info[8] = 0;
        } else {
            info[8] = lpBondHelperFrom(_bond).getPayout(_bond, _token, _amount);
        }

        info[9] = IBondDespository(_bond).currentDebt();
        info[10] = IBondDespository(_bond).maxDebt();
    }

    function lpBondHelperFrom(address _bond) public view returns(ILPBondHelper) {
        address helper = mapBondToLPBondHelper[_bond];
        require(helper != address(0));
        return ILPBondHelper(helper);
    }

    function discountOf(address _user) public view returns(uint256 discount_, uint256 endTime_) {
        discount_ = 0;
        endTime_ = 0;
        if (discount != address(0)) {
            discount_ = IDiscount(discount).discountOf(_user);
            endTime_ = IDiscount(discount).endTime();
        }
    }
}