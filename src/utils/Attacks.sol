// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * Attacks are represented using 192 bits. Bit layout:
 * [64 bits: whether a cell in untouched | 64 bits: whether a cell is a miss | 64 bits: whether a cell is a hit]
 * Each 64-bit piece has a layout like this:
 * [bit for 63rd cell | bit for 62nd cell | bit for 0th cell]
 */
library Attacks {
    // initializer for new battle
    uint192 internal constant EMPTY_ATTACKS = 0xFFFFFFFFFFFFFFFF << 128;

    uint8 internal constant EMPTY = 0;
    uint8 internal constant MISS = 1;
    uint8 internal constant HIT = 2;

    function isOfType(
        uint192 attacks,
        uint8 attackType,
        uint8 cell
    ) internal pure returns (bool) {
        uint8 shiftBy = (64 * (2 - attackType)) + cell;
        return ((attacks >> shiftBy) & 0x1) == 1;
    }

    function markAs(
        uint192 attacks,
        uint8 attackType,
        uint8 cell
    ) internal pure returns (uint192 updatedAttacks) {
        uint64 oneMask = uint64(0x1 << cell);
        uint64 zeroMask = ~oneMask;
        for (uint8 i = 0; i < 3; i++) {
            uint8 shiftChunkBy = 64 * (2 - i);
            uint64 chunk = uint64(attacks >> shiftChunkBy);
            if (i == attackType) {
                chunk |= oneMask;
            } else {
                chunk &= zeroMask;
            }
            updatedAttacks |= (uint192(chunk) << shiftChunkBy);
        }
    }

    function numberOfEmptyCells(uint192 attacks) internal pure returns (uint8) {
        return hammingDistance64(uint64(attacks >> 128));
    }

    function numberOfMisses(uint192 attacks) internal pure returns (uint8) {
        return hammingDistance64(uint64(attacks >> 64));
    }

    function numberOfHits(uint192 attacks) internal pure returns (uint8) {
        return hammingDistance64(uint64(attacks));
    }

    function hasWon(uint192 attacks) internal pure returns (bool) {
        return numberOfHits(attacks) == 21; // 21 is total number of cells occupied by ships
    }

    function hammingDistance64(uint64 v)
        private
        pure
        returns (uint8 countOfOnes)
    {
        // TODO implement this for uint64
        return
            uint8(
                hammingDistance32(uint32(v)) +
                    hammingDistance32(uint32(v >> 32))
            );
    }

    function hammingDistance32(uint32 v)
        private
        pure
        returns (uint32 countOfOnes)
    {
        // See http://graphics.stanford.edu/~seander/bithacks.html (Counting bits set, in parallel section)
        // Also see https://stackoverflow.com/questions/14555607/number-of-bits-set-in-a-number
        // and https://stackoverflow.com/questions/15233121/calculating-hamming-weight-in-o1
        v = v - ((v >> 1) & 0x55555555);
        v = (v & 0x33333333) + ((v >> 2) & 0x33333333);
        return (((v + (v >> 4)) & 0xF0F0F0F) * 0x1010101) >> 24;
    }
}
