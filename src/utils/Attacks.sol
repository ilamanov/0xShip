// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * Attacks are represented similar to board
 * 8x8=64 cells, 4 bits per cell. 256 bit per total. So to be used with uint256
 * But value are not contiguos. First 64 bits indicate whether each cell is untouched
 * next 64 bits indicate wheter the hit at a cell was a miss
 * next 64 indicate a hit
 * next 64 a destroy
 */
library Attacks {
    uint256 internal constant EMPTY_ATTACKS = 0xFFFFFFFFFFFFFFFF << 192;

    // TODO add things like how many cells left, isThereAPendingHit, etc other helpers that can be used by generals

    function isUntouched(uint256 attacks, uint8 cell)
        internal
        pure
        returns (bool)
    {
        // shift 64*3=192 bits to the right (leftmost bits indicate whether a miss1)
        // get the value at the cell by ANDing with 0x1<<cell. ((attacks >> 64) & (0x1 << cell)) which is equivalent to (attacks >> (64 + cell)) & 0x1 (not quite because now the value is at the very right)
        return ((attacks >> (192 + cell)) & 0x1) == 1;
    }

    // TODO is is possible to update attacks var in place instead of returning a new val? if so update the Game contract as well
    function markAsMiss(uint256 attacks, uint8 cell)
        internal
        pure
        returns (uint256 updatedAttacks)
    {
        return markIthQuarter(attacks, cell, 1);
    }

    function markAsHit(uint256 attacks, uint8 cell)
        internal
        pure
        returns (uint256 updatedAttacks)
    {
        return markIthQuarter(attacks, cell, 2);
    }

    function markAsDestroyed(uint256 attacks, uint8 cell)
        internal
        pure
        returns (uint256 updatedAttacks)
    {
        return markIthQuarter(attacks, cell, 3);
    }

    function markIthQuarter(
        uint256 attacks,
        uint8 cell,
        uint8 index
    ) private pure returns (uint256) {
        uint256 oneMask = 0x1 << cell;
        uint256 zeroMask = ~oneMask;
        uint256 updatedAttacks;
        for (uint8 i = 0; i < 4; i++) {
            uint8 shiftQuarterBy = 64 * (3 - i);
            uint256 quarter = (attacks >> shiftQuarterBy) & 0xFFFFFFFFFFFFFFFF;
            if (i == index) {
                quarter |= oneMask;
            } else {
                quarter &= zeroMask;
            }
            updatedAttacks |= (quarter << shiftQuarterBy);
        }

        return updatedAttacks;
    }
}
