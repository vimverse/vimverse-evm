// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IRebate.sol";

contract Discount is OwnableUpgradeable {

    mapping (address=>uint256) public userDiscount;
    uint256 public startTime;
    uint256 public endTime;
    address public rebate;
    
    function initialize(
    ) external initializer {
        __Ownable_init();
    }

    function setRebate(address _rebate) external onlyOwner {
        require(_rebate != address(0));
        rebate = _rebate;
    }

    function setDiscountTime(uint256 _startTime, uint256 _endTime) external onlyOwner {
        require(_startTime > 0 && _endTime > _startTime && _endTime > block.timestamp);
        startTime = _startTime;
        endTime = _endTime;
    }

    function setUserDiscount(address[] memory _users, uint256 _discount) external onlyOwner {
        require(_discount >= 80);
        for (uint256 i = 0; i < _users.length; ++i) {
            userDiscount[_users[i]] = _discount;
        }
    }

    function discountOf(address _user) external view returns (uint256) {
        if (block.timestamp < startTime || block.timestamp > endTime) {
            return 100;
        }

        uint256 off = userDiscount[_user];
        if (off == 0) {
            return 100;
        }
        
        return off;
    }
}