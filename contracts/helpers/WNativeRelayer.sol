// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../interfaces/IWETH.sol";
import "./ReentrancyGuard.sol";
import "./Ownable.sol";

contract WNativeRelayer is Ownable, ReentrancyGuard {
  address public wnative;
  mapping(address => bool) public okCallers;

  constructor(address _wnative) public {
    wnative = _wnative;
  }

  modifier onlyWhitelistedCaller() {
    require(okCallers[msg.sender] == true, "WNativeRelayer::onlyWhitelistedCaller:: !okCaller");
    _;
  }

  function setCallerOk(address caller, bool isOk) external onlyOwner {
    okCallers[caller] = isOk;
  }

  function withdraw(uint256 _amount) external onlyWhitelistedCaller nonReentrant {
    IWETH(wnative).withdraw(_amount);
    (bool success, ) = msg.sender.call{value: _amount}("");
    require(success, "WNativeRelayer::onlyWhitelistedCaller:: can't withdraw");
  }

  receive() external payable {}
}