// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IPriceCalculator {
    function priceOfWETH() external view returns(uint256);
    function priceOfToken(address token) external view returns(uint256);
    function setTokenV3Pool(address _asset, address _v3Pool) external;
}