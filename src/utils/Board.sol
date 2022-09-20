// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * Board is 8x8 packed into uint64.
 * 1 indicates that there is a ship, 0 indicates no ship
 */
library Board {
    function isHit(uint64 board, uint8 cell) internal pure returns (bool) {
        return ((board >> cell) & 0x1) == 1;
    }

    // function isDestroyed(uint64 board, uint256 attacks, uint8 cell) internal pure returns (bool) {
    //     return ((board >> cell) & 0x1) == 1;
    // }
}
