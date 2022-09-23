// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * Attacks are represented using 256 bits but only use the rightmost 192 bits. Bit layout of the 192 bits:
 * [64 bits: whether a cell in untouched | 64 bits: whether a cell is a miss | 64 bits: whether a cell is a hit]
 * Each 64-bit piece has a layout like this:
 * [bit for 63rd cell | bit for 62nd cell | bit for 0th cell]
 */
library Attacks {
    // initializer for new battle
    uint256 internal constant EMPTY_ATTACKS = 0xFFFFFFFFFFFFFFFF << 128;

    uint256 internal constant EMPTY = 0;
    uint256 internal constant MISS = 1;
    uint256 internal constant HIT = 2;

    function isOfType(
        uint256 attacks,
        uint256 attackType,
        uint256 cellIdx
    ) internal pure returns (bool) {
        uint256 shiftBy = (64 * (2 - attackType)) + cellIdx;
        return ((attacks >> shiftBy) & 0x1) == 1;
    }

    function markAs(
        uint256 attacks,
        uint256 attackType,
        uint256 cellIdx
    ) internal pure returns (uint256 updatedAttacks) {
        uint256 oneMask = 0x1 << cellIdx;
        uint256 zeroMask = (~oneMask) & 0xFFFFFFFFFFFFFFFF;
        for (uint256 i = 0; i < 3; i++) {
            uint256 shiftChunkBy = 64 * (2 - i);
            uint256 chunk = (attacks >> shiftChunkBy) & 0xFFFFFFFFFFFFFFFF;
            if (i == attackType) {
                chunk |= oneMask;
            } else {
                chunk &= zeroMask;
            }
            updatedAttacks |= (chunk << shiftChunkBy);
        }
    }

    function numberOfEmptyCells(uint256 attacks)
        internal
        pure
        returns (uint256)
    {
        return hammingDistance64((attacks >> 128) & 0xFFFFFFFFFFFFFFFF);
    }

    function numberOfMisses(uint256 attacks) internal pure returns (uint256) {
        return hammingDistance64((attacks >> 64) & 0xFFFFFFFFFFFFFFFF);
    }

    function numberOfHits(uint256 attacks) internal pure returns (uint256) {
        return hammingDistance64(attacks & 0xFFFFFFFFFFFFFFFF);
    }

    function hasWon(uint256 attacks) internal pure returns (bool) {
        return numberOfHits(attacks) == 21; // 21 is total number of cells occupied by ships
    }

    function hammingDistance64(uint256 v)
        private
        pure
        returns (uint256 countOfOnes)
    {
        // TODO implement this for uint64
        return hammingDistance32(v & 0xFFFFFFFF) + hammingDistance32(v >> 32);
    }

    function hammingDistance32(uint256 v)
        private
        pure
        returns (uint256 countOfOnes)
    {
        // See http://graphics.stanford.edu/~seander/bithacks.html (Counting bits set, in parallel section)
        // Also see https://stackoverflow.com/questions/14555607/number-of-bits-set-in-a-number
        // and https://stackoverflow.com/questions/15233121/calculating-hamming-weight-in-o1
        v = v - ((v >> 1) & 0x55555555);
        v = (v & 0x33333333) + ((v >> 2) & 0x33333333);
        return (((v + (v >> 4)) & 0xF0F0F0F) * 0x1010101) >> 24;
    }
}
