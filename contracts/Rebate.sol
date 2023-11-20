// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IWNativeRelayer.sol";
import "./interfaces/IDiscount.sol";
import "./library/SafeERC20.sol";
import "./library/SafeMath.sol";

contract Rebate is OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct Referrer {
        bool isReferrer;
        address[2] referrerLinks;
    }

    mapping(address => Referrer) public referrers;
    uint256[2] public referBonus;
    address public WETH;
    address public  wNativeRelayer;
    mapping(address => bool) public authControllers;
    mapping (address => uint256) public mapCumulativeRewards;
    uint256 public minPayAmount;
    address public discount;
    bool public disableRebate;

    function initialize(
        address _WETH,
        address _wNativeRelayer
    ) external initializer {
        require(_WETH != address(0));
        require(_wNativeRelayer != address(0));

        __Ownable_init();

        referBonus[0] = 10;
        referBonus[1] = 10;

        WETH = _WETH;
        wNativeRelayer = _wNativeRelayer;
        minPayAmount = 500 ether;
        disableRebate = false;
    }

    function setDiscount( address _discount ) external onlyOwner() {
        require(_discount != address(0));
        discount = _discount;
    }

    function setReferBonus(uint256[2] memory _referBonus) external onlyOwner {
        referBonus = _referBonus;
    }

    function setAuthControllers(address _contracts, bool _enable) external onlyOwner {
        authControllers[_contracts] = _enable;
    }

    function setMinPayAmount(uint256 _amount) external onlyOwner {
        minPayAmount = _amount;
    }

    function isValidReferrer(address _referrer) external view returns(bool){
        return referrers[_referrer].isReferrer;
    }

    function setDisableRebate(bool _disableRebate) external onlyOwner {
        disableRebate = _disableRebate;
    }

    function rebateTo(address _referrer, address _token, uint256 _amount) external returns(uint256) {
        require(authControllers[msg.sender] == true, "no auth");
        if (disableRebate) {
            return _amount;
        }

        uint256[2] memory bonusAmount;
        address[2] memory referAddr = referrers[tx.origin].referrerLinks;
        if (referAddr[0] == address(0)) {
            if (_referrer != address(0) && referrers[_referrer].isReferrer) {
                referAddr[0] = _referrer;
                referAddr[1] = referrers[_referrer].referrerLinks[0];
                referrers[tx.origin].referrerLinks = referAddr;
            }
        } else if (referAddr[1] == address(0)) {
            _referrer = referAddr[0];
            if (referrers[_referrer].isReferrer) {
                referAddr[1] = referrers[_referrer].referrerLinks[0];
                if (referAddr[1] != address(0)) {
                    referrers[tx.origin].referrerLinks[1] = referAddr[1];   
                }
            }
        }

        if (_amount >= minPayAmount && referrers[tx.origin].isReferrer == false) {
            referrers[tx.origin].isReferrer = true;
        }

        uint256 d = discountOf(tx.origin);
        for (uint256 i = 0; i < 2; ++i) {
            if (d < 100 && i > 0) {
                break;
            }
            if (referAddr[i] != address(0)) {
                bonusAmount[i] = _amount * referBonus[i] / 100;
            } else {
                bonusAmount[i] = 0;
            }
        }

        uint256 totalBonusAmount = bonusAmount[0] + bonusAmount[1];
        if (totalBonusAmount == 0) {
            return _amount;
        }

        if (_token == WETH) {
            IERC20(_token).safeTransferFrom(msg.sender, wNativeRelayer, totalBonusAmount);
            IWNativeRelayer(wNativeRelayer).withdraw(totalBonusAmount);
        } else {
            IERC20(_token).safeTransferFrom(msg.sender, address(this), totalBonusAmount);
        }

        for (uint256 i = 0; i < 2; ++i) {
            if (bonusAmount[i] > 0) {
                if (_token == WETH) {
                    SafeERC20.safeTransferETH(referAddr[i], bonusAmount[i]);
                } else {
                    IERC20(_token).safeTransfer(referAddr[i], bonusAmount[i]);
                }
                mapCumulativeRewards[referAddr[i]] += bonusAmount[i];
            }
        }

        _amount = _amount.sub(totalBonusAmount);
        return _amount;
        
    }

    function getReferrerInfo(address _addr) public view returns(bool, uint256, address) {
        bool r = referrers[_addr].isReferrer;
        uint256 rewards = mapCumulativeRewards[_addr];
        address referrer = referrers[_addr].referrerLinks[0];
        return (r, rewards, referrer);
    }

    function getReferrer(address _addr) public view returns(address[2] memory) {
        return referrers[_addr].referrerLinks;
    }

    function withdrawBEP20(address _tokenAddress, address _to, uint256 _amount) public {
        require(authControllers[msg.sender] == true, "no auth");
        uint256 tokenBal = IERC20(_tokenAddress).balanceOf(address(this));
        if (_amount == 0 || _amount >= tokenBal) {
            _amount = tokenBal;
        }

        if (_tokenAddress == WETH) {
            SafeERC20.safeTransferETH(_to, _amount);
        } else {
            IERC20(_tokenAddress).transfer(_to, _amount);
        }
    }

    function withdrawETH(address _to) public {
        require(authControllers[msg.sender] == true, "no auth");
        if (address(this).balance > 0) {
            SafeERC20.safeTransferETH(_to, address(this).balance);
        }
    }

    receive() external payable {}

    function discountOf(address _user) public view returns(uint256) {
        if (discount != address(0)) {
            return IDiscount(discount).discountOf(_user);
        }
        return 100;
    }
}