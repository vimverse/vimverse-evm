// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./interfaces/IERC20.sol";

contract StakingWarmup {

    address public immutable staking;
    address public immutable sVim;

    constructor ( address _staking, address _sVim ) public {
        require( _staking != address(0) );
        staking = _staking;
        require( _sVim != address(0) );
        sVim = _sVim;
    }

    function retrieve( address _staker, uint _amount ) external {
        require( msg.sender == staking );
        IERC20( sVim ).transfer( _staker, _amount );
    }
}