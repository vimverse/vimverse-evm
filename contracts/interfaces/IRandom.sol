// SPDX-License-Identifier: MIT LICENSE 

pragma solidity ^0.6.12;

interface IRandom {
    function randomseed(uint256 _seed) external view returns (uint256);
    function multiRandomSeeds(uint256 _seed, uint256 _count) external view returns (uint256[] memory);
}