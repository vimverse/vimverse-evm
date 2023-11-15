// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IBond {
    function payoutFor( uint _value ) external view returns ( uint );
    function deposit( 
        uint _amount, 
        uint _maxPrice,
        address _depositor,
        address _referrer
    ) external returns ( uint );
    
    function bondPrice() external view returns ( uint price_ );
    function principle() external view returns(address token_);
    function Vim() external view returns (address token_);
    function isLiquidityBond() external view returns (bool);

    function redeem( address _recipient, bool _stake ) external returns ( uint );
    function pendingPayoutFor( address _depositor ) external view returns ( uint pendingPayout_ );
}