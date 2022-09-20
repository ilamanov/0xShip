// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * Fleet is packed into uint64
 * [4 empty bits][6 bits for patrol start coords][6 bits for patrol end coords][...same for other fleet]
 */
library Fleet {
    uint64 internal constant EMPTY_FLEET = 0;

    function getPatrolCoordsStart(uint64 fleet) internal pure returns (uint8) {
        // each coord takes up 6 bits. There are 9 coords to the right. So need to shift right by 54 bits
        // cast to 8-bitm and mask out the initial 2 bits
        return uint8(fleet >> 54) & 0x3F;
    }

    function getPatrolCoordsEnd(uint64 fleet) internal pure returns (uint8) {
        // Shift right and mask out leading bits
        return uint8(fleet >> 48) & 0x3F;
    }

    function getFirstDestroyerCoordsStart(uint64 fleet)
        internal
        pure
        returns (uint8)
    {
        return uint8(fleet >> 42) & 0x3F;
    }

    function getFirstDestroyerCoordsEnd(uint64 fleet)
        internal
        pure
        returns (uint8)
    {
        return uint8(fleet >> 36) & 0x3F;
    }

    function getSecondDestroyerCoordsStart(uint64 fleet)
        internal
        pure
        returns (uint8)
    {
        return uint8(fleet >> 30) & 0x3F;
    }

    function getSecondDestroyerCoordsEnd(uint64 fleet)
        internal
        pure
        returns (uint8)
    {
        return uint8(fleet >> 24) & 0x3F;
    }

    function getCarrierCoordsStart(uint64 fleet) internal pure returns (uint8) {
        return uint8(fleet >> 18) & 0x3F;
    }

    function getCarrierCoordsEnd(uint64 fleet) internal pure returns (uint8) {
        return uint8(fleet >> 12) & 0x3F;
    }

    function getBattleshipCoordsStart(uint64 fleet)
        internal
        pure
        returns (uint8)
    {
        return uint8(fleet >> 6) & 0x3F;
    }

    function getBattleshipCoordsEnd(uint64 fleet)
        internal
        pure
        returns (uint8)
    {
        return uint8(fleet) & 0x3F;
    }
}
