// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./interfaces/IERC20.sol";
import "./interfaces/IStaking.sol";

contract StakingHelper {

    address public immutable staking;
    address public immutable Vim;

    constructor ( address _staking, address _Vim ) public {
        require( _staking != address(0) );
        staking = _staking;
        require( _Vim != address(0) );
        Vim = _Vim;
    }

    function stake( uint _amount ) external {
        IERC20( Vim ).transferFrom( msg.sender, address(this), _amount );
        IERC20( Vim ).approve( staking, _amount );
        IStaking( staking ).stake( _amount, msg.sender );
        IStaking( staking ).claim( msg.sender );
    }
}