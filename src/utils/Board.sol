// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

error CantWrapShip(uint256 shipType);
error ShipCollidesOrTooClose(uint256 shipType);

/**
 * Board is represented using 256 bits, but only rightmost 192 bits are used. Bit layout of the 192 bits:
 * [3 bits: 63rd cell | 3 bits: 62nd cell | ... | 3 bits: 0th cell]
 * Each cell is 3 bits and it indicates shipType (1,2,3,4,5) or empty (0) at that cell.
 * The shipType values are from Fleet.PATROL, Fleet.DESTROYER1, etc.
 */
library Board {
    function getShipAt(uint256 board, uint256 cellIdx)
        internal
        pure
        returns (uint256)
    {
        return (board >> (cellIdx * 3)) & 0x7;
    }

    // ---------- Helper to build a board from its fleet representation ----------
    struct BuildData {
        uint256 board;
        uint256 occupancyGrid; // all 3 bits at each cell will be 1 if there is a ship at a given cell
    }

    // assumes startCoord < endCoord
    function placeShip(
        BuildData memory buildData,
        uint256 startCoord,
        uint256 endCoord,
        uint256 shipType
    ) internal pure {
        // TODO is there a constant time bit operation that we can use instead of a loop in the function?
        uint256 startY = startCoord >> 3; // divide by 8
        uint256 endY = endCoord >> 3;
        uint256 startX = startCoord % 8;
        uint256 endX = endCoord % 8;

        if (startX > endX) revert CantWrapShip(shipType);

        uint256 ship; // cells occupied by this ship
        for (uint256 y = startY; y <= endY; y++) {
            for (uint256 x = startX; x <= endX; x++) {
                // to mark the cell we need to do shipType << (3 * cellIdx)
                // where cellIdx = y * 8 + x = (y << 3) + x
                ship |= shipType << (3 * ((y << 3) + x));
            }
        }
        if (ship & buildData.occupancyGrid != 0)
            revert ShipCollidesOrTooClose(shipType);

        if (startX > 0) {
            startX--;
        }
        if (startY > 0) {
            startY--;
        }
        if (endX < 7) {
            endX++;
        }
        if (endY < 7) {
            endY++;
        }
        uint256 shipAndAdjacent; // cells occupied by this ship and a padding of 1
        // You can't place another ship close than this padding
        for (uint256 y = startY; y <= endY; y++) {
            for (uint256 x = startX; x <= endX; x++) {
                // we do the same as in the above loop but use 111=0x7 instead of shipType
                shipAndAdjacent |= 0x7 << (3 * ((y << 3) + x));
            }
        }

        buildData.board |= ship;
        buildData.occupancyGrid |= shipAndAdjacent;
    }
}
