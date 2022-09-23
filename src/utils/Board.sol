// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

error CantWrapShip(uint8 shipType);
error ShipCollidesOrTooClose(uint8 shipType);

/**
 * Board is 192 bits. Bit layout:
 * [3 bits: 63rd cell | 3 bits: 62nd cell | ... | 3 bits: 0th cell]
 * Each cell is 3 bits and it indicates shipType (1,2,3,4,5) or empty (0) at that cell.
 * The shipType values are from Fleet.PATROL, Fleet.DESTROYER1, etc.
 */
library Board {
    function getShipAt(uint192 board, uint8 cellIdx)
        internal
        pure
        returns (uint8)
    {
        return uint8((board >> (cellIdx * 3)) & 0x7);
    }

    // ---------- Helper to build a board from its fleet representation ----------
    struct BuildData {
        uint192 board;
        uint192 occupancyGrid; // all 3 bits at each cell will be 1 if there is a ship at a given cell
    }

    // assumes startCoord < endCoord
    function placeShip(
        BuildData memory buildData,
        uint8 startCoord,
        uint8 endCoord,
        uint8 shipType
    ) internal pure {
        // TODO is there a constant time bit operation that we can use instead of a loop in the function?
        uint8 startY = startCoord >> 3; // divide by 8
        uint8 endY = endCoord >> 3;
        uint8 startX = startCoord % 8;
        uint8 endX = endCoord % 8;

        if (startX > endX) revert CantWrapShip(shipType);

        uint192 ship; // cells occupied by this ship
        for (uint8 y = startY; y <= endY; y++) {
            for (uint8 x = startX; x <= endX; x++) {
                uint8 cellIdx = (y << 3) + x;
                uint192 mask = uint192(shipType) << (3 * cellIdx);
                // multiply by 3 in the mask because each cell takes up 3 bits
                ship |= mask;
            }
        }

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
        uint192 shipAndAdjacent; // cells occupied by this ship and a padding of 1
        // You can't place another ship close than this padding
        for (uint8 y = startY; y <= endY; y++) {
            for (uint8 x = startX; x <= endX; x++) {
                uint8 cellIdx = (y << 3) + x;
                uint192 mask = uint192(0x7) << (cellIdx * 3);
                shipAndAdjacent |= mask;
            }
        }

        if (ship & buildData.occupancyGrid != 0)
            revert ShipCollidesOrTooClose(shipType);

        buildData.board |= ship;
        buildData.occupancyGrid |= shipAndAdjacent;
    }
}
