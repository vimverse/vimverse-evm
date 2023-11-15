// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

library Fraction {
    uint8 private constant RESOLUTION = 64;

    function fraction(uint64 numerator, uint64 denominator) internal pure returns (uint64) {
        require(denominator > 0, 'FixedPoint::fraction: division by zero');
        if (numerator == 0) return 0;

        uint128 result = (uint128(numerator) << RESOLUTION) / denominator;
        result = result / 18446744073;

        require(result <= uint64(-1), 'FixedPoint::fraction: overflow');
        return uint64(result);
    }
}