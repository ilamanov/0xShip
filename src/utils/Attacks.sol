// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * Attacks are represented using 256 bits but only the rightmost 192 bits are used.
 * Bit layout of the 192 bits:
 * [64 bits: whether a cell is a hit | 64 bits: whether a cell is a miss | 64 bits: whether a cell is untouched]
 * Each 64-bit piece has a layout like this:
 * [bit for 63rd cell | bit for 62nd cell | bit for 0th cell]
 */
library Attacks {
    // initializer for new battle. All cells are untouched
    uint256 internal constant EMPTY_ATTACKS = 0xFFFFFFFFFFFFFFFF;

    uint256 internal constant UNTOUCHED = 0;
    uint256 internal constant MISS = 1;
    uint256 internal constant HIT = 2;

    // zero_mask is same as [...63 zeros ... 1 ... 63 zeros ... 1 ... 63 zeros ... 1]
    uint256 private constant FIRST_CELL = 0x100000000000000010000000000000001;

    function isOfType(
        uint256 attacks,
        uint256 attackType,
        uint256 cellIdx
    ) internal pure returns (bool) {
        // cell of interest is at shiftBy = attackType * 64 + cellIdx = (attackType << 6) + cellIdx
        // need to check whether attacks & (1 << shiftBy) is non-zero
        return (attacks & (1 << ((attackType << 6) + cellIdx))) > 0;
    }

    function markAs(
        uint256 attacks,
        uint256 attackType,
        uint256 cellIdx
    ) internal pure returns (uint256 updatedAttacks) {
        // zeroMask is for zeroing out all attackTypes for a given cell
        uint256 zeroMask = ~(FIRST_CELL << cellIdx);
        // oneMask is for setting bit at attackType to 1
        uint256 oneMask = 1 << ((attackType << 6) + cellIdx);
        return (attacks & zeroMask) | oneMask;
    }

    function numberOfEmptyCells(uint256 attacks)
        internal
        pure
        returns (uint256)
    {
        return hammingDistance64((attacks >> UNTOUCHED) & 0xFFFFFFFFFFFFFFFF);
    }

    function numberOfMisses(uint256 attacks) internal pure returns (uint256) {
        return hammingDistance64((attacks >> MISS) & 0xFFFFFFFFFFFFFFFF);
    }

    function numberOfHits(uint256 attacks) internal pure returns (uint256) {
        return hammingDistance64((attacks >> HIT) & 0xFFFFFFFFFFFFFFFF);
    }

    function hasWon(uint256 attacks) internal pure returns (bool) {
        return numberOfHits(attacks) == 21; // 21 is total number of cells occupied by ships
    }

    function hammingDistance64(uint256 x) internal pure returns (uint256) {
        // TODO implement this for uint64
        return hammingDistance32(x & 0xFFFFFFFF) + hammingDistance32(x >> 32);
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
        return uint32(((v + (v >> 4)) & 0xF0F0F0F) * 0x1010101) >> 24;
    }
}
