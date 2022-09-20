// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 */
library BoardBuilder {
    struct BuildData {
        uint64 board;
        uint64 occupancyGrid;
    }

    function placeShip(
        BuildData memory buildData, // TODO need memory? is it possible to update in memory without creating a new return val?
        uint8 startCoord,
        uint8 endCoord
    ) internal pure returns (BuildData memory updatedBuildData) {
        // TODO is there a constant time bit operation that we can use instead of a loop?
        uint8 startY = startCoord >> 3; // divide by 8
        uint8 endY = startCoord >> 3;
        uint8 startX = startCoord % 8;
        uint8 endX = endCoord % 8;
        uint64 ship; // cells occupied by this ship
        for (uint8 y = startY; y <= endY; y++) {
            for (uint8 x = startX; x <= endX; x++) {
                ship = ship | uint64(0x1 << ((y << 3) + x));
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
        uint64 shipAndAdjacent; // cells occupied by this ship and a padding of 1. You can't place another ship close than this padding
        for (uint8 y = startY; y <= endY; y++) {
            for (uint8 x = startX; x <= endX; x++) {
                shipAndAdjacent =
                    shipAndAdjacent |
                    uint64(0x1 << ((y << 3) + x));
            }
        }

        require(
            ship & buildData.occupancyGrid == 0,
            "A ship collides or too close to other ship"
        );

        return
            BuildData(
                buildData.board | ship,
                buildData.occupancyGrid | shipAndAdjacent
            );
    }
}
