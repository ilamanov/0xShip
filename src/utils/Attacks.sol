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
        uint256 cellIdx,
        uint256 attackType
    ) internal pure returns (bool) {
        // cell of interest is at shiftBy = attackType * 64 + cellIdx = (attackType << 6) + cellIdx
        // need to check whether attacks & (1 << shiftBy) is non-zero
        return (attacks & (1 << ((attackType << 6) + cellIdx))) > 0;
    }

    function markAs(
        uint256 attacks,
        uint256 cellIdx,
        uint256 attackType
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
        return
            hammingDistance64(
                (attacks >> (UNTOUCHED << 6)) & 0xFFFFFFFFFFFFFFFF
            );
    }

    function numberOfMisses(uint256 attacks) internal pure returns (uint256) {
        return hammingDistance64((attacks >> (MISS << 6)) & 0xFFFFFFFFFFFFFFFF);
    }

    function numberOfHits(uint256 attacks) internal pure returns (uint256) {
        return hammingDistance64((attacks >> (HIT << 6)) & 0xFFFFFFFFFFFFFFFF);
    }

    function hasWon(uint256 attacks) internal pure returns (bool) {
        // hasWon is when numberOfHits == 21
        return
            hammingDistance64((attacks >> (HIT << 6)) & 0xFFFFFFFFFFFFFFFF) ==
            21; // 21 is total number of cells occupied by ships
    }

    function hammingDistance64(uint256 x) internal pure returns (uint256) {
        // Computes hamming distance (weight) of a 64-bit number.
        // Hamming distance is number of bits that are set to 1. See:
        // - https://en.wikipedia.org/wiki/Hamming_weight
        // - https://stackoverflow.com/questions/2709430/count-number-of-bits-in-a-64-bit-long-big-integer
        // and for 32-bit version see:
        // - http://graphics.stanford.edu/~seander/bithacks.html (Counting bits set, in parallel section)
        // - https://stackoverflow.com/questions/14555607/number-of-bits-set-in-a-number
        // - https://stackoverflow.com/questions/15233121/calculating-hamming-weight-in-o1

        // implementation from https://en.wikipedia.org/wiki/Hamming_weight
        x -= (x >> 1) & 0x5555555555555555; // put count of each 2 bits into those 2 bits
        x = (x & 0x3333333333333333) + ((x >> 2) & 0x3333333333333333); // put count of each 4 bits into those 4 bits
        x = (x + (x >> 4)) & 0x0f0f0f0f0f0f0f0f; // put count of each 8 bits into those 8 bits
        return uint64(x * 0x0101010101010101) >> 56; // returns left 8 bits of x + (x<<8) + (x<<16) + (x<<24) + ...
    }
}
