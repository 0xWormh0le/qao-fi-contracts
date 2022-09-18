// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;
pragma experimental ABIEncoderV2;

library PreciseUnitMath {

    // The number One in precise units.
    uint256 constant internal PRECISE_UNIT = 10 ** 18;

    /**
     * @dev Getter function since constants can't be read directly from libraries.
     */
    function preciseUnit() internal pure returns (uint256) {
        return PRECISE_UNIT;
    }

    function preciseDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * PRECISE_UNIT / b;
    }
}
