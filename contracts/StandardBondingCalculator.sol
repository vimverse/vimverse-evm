// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./library/FixedPoint.sol";
import "./library/SafeMath.sol";
import "./interfaces/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IUniswapV2ERC20 {
    function totalSupply() external view returns (uint);
}

interface IUniswapV2Pair is IUniswapV2ERC20 {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns ( address );
    function token1() external view returns ( address );
}

interface IBondingCalculator {
  function valuation( address pair_, uint amount_ ) external view returns ( uint _value );
}

contract BondingCalculator is IBondingCalculator, OwnableUpgradeable {

    using FixedPoint for *;
    using SafeMath for uint;
    using SafeMath for uint112;

    address public Vim;

    function initialize( address _Vim ) external initializer {
        __Ownable_init();
        require( _Vim != address(0) );
        Vim = _Vim;
    }

    function getKValue( address _pair ) public view returns( uint k_ ) {
        uint token0 = IERC20( IUniswapV2Pair( _pair ).token0() ).decimals();
        uint token1 = IERC20( IUniswapV2Pair( _pair ).token1() ).decimals();
        uint decimals = token0 + token1;
        uint decimalsPair = IERC20( _pair ).decimals();

        (uint reserve0, uint reserve1, ) = IUniswapV2Pair( _pair ).getReserves();
        if (decimals > decimalsPair) {
            k_ = reserve0.mul(reserve1).div(10 ** (decimals - decimalsPair));
        } else {
            k_ = reserve0.mul(reserve1).mul(10 ** (decimalsPair - decimals));
        }
    }

    function getTotalValue( address _pair ) public view returns ( uint _value ) {
        _value = getKValue( _pair ).sqrrt().mul(2);
    }

    function valuation( address _pair, uint amount_ ) external view override returns ( uint _value ) {
        uint totalValue = getTotalValue( _pair );
        uint totalSupply = IUniswapV2Pair( _pair ).totalSupply();
        if (totalSupply == 0) {
            return 0;
        }

        _value = totalValue.mul( FixedPoint.fraction( amount_, totalSupply ).decode112with18() ).div( 1e18 );
    }

    function markdown( address _pair ) external view returns ( uint ) {
        ( uint reserve0, uint reserve1, ) = IUniswapV2Pair( _pair ).getReserves();
        if (reserve0 == 0 || reserve1 == 0) {
            return 0;
        }

        uint reserve;
        if ( IUniswapV2Pair( _pair ).token0() == Vim ) {
            reserve = reserve1;
        } else {
            reserve = reserve0;
        }
        return reserve.mul( 2 * ( 10 ** IERC20( Vim ).decimals() ) ).div( getTotalValue( _pair ) );
    }
}