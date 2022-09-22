// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Board.sol";

error CoordsAreNotSorted(uint8 shipType);
error NotRightSizeOrOrientation(uint8 shipType);

/**
 * Fleet is packed into uint64. Bit layout:
 * [4 empty bits | 6 bits: patrol start coord | 6 bits: patrol end coord | 6 bits: destroyer1 start coord | ...]
 * Each coord is 6 bits and it's an index into the 8x8 board, i.e. [0, 64)
 */
library Fleet {
    // initializer for undiscovered fleet
    uint64 internal constant EMPTY_FLEET = 0;

    // ship types
    uint8 internal constant EMPTY = 0;
    uint8 internal constant PATROL = 1;
    uint8 internal constant DESTROYER1 = 2;
    uint8 internal constant DESTROYER2 = 3;
    uint8 internal constant CARRIER = 4;
    uint8 internal constant BATTLESHIP = 5;

    // ship sizes
    uint8 internal constant PATROL_LENGTH = 2;
    uint8 internal constant DESTROYER_LENGTH = 3;
    uint8 internal constant CARRIER_LENGTH = 4;
    uint8 internal constant CARRIER_WIDTH = 2;
    uint8 internal constant BATTLESHIP_LENGTH = 5;

    function getCoordsStart(uint64 fleet, uint8 shipType)
        internal
        pure
        returns (uint8)
    {
        // each ship takes up 2*6=12 bits. Need to shift right by
        // correct number of bits and take only the remaining 6 bits
        // cast to 8-bitm and mask out the initial 2 bits
        return uint8(fleet >> (66 - (12 * shipType))) & 0x3F;
    }

    function getCoordsEnd(uint64 fleet, uint8 shipType)
        internal
        pure
        returns (uint8)
    {
        return uint8(fleet >> (60 - (12 * shipType))) & 0x3F;
    }

    // populate toFleet with the coords of shipType from fromFleet
    function copyShipTo(
        uint64 fromFleet,
        uint64 toFleet,
        uint8 shipType
    ) internal pure returns (uint64) {
        uint8 shiftBy = 60 - 12 * shipType;
        uint64 shipCoords = (fromFleet >> shiftBy) & 0xFFF; // shift and take last 12 bits
        shipCoords <<= shiftBy; // shift back to its place
        return toFleet | shipCoords; // notice that toFleet is assumed to have all zeros
        // in the shipType's position, i.e. it does not manually clear out the bits
    }

    using Board for Board.BuildData;

    // only used in Game.revealBoard to validate the fleet and store the board representation
    // of the fleet for faster lookup
    function validateFleetAndConvertToBoard(uint64 fleet)
        internal
        pure
        returns (uint192)
    {
        // make sure that the fleet is properly formatted: ships have the right size and
        // orientation (either horizontal or vertical)

        // ------------------------------ PATROL ship validation ------------------------------
        uint8 patrolStart = getCoordsStart(fleet, PATROL);
        uint8 patrolEnd = getCoordsEnd(fleet, PATROL);
        // start and end are guaranteed to be within [0, 64)
        // because we mask out the leading bits in getCoords[X]
        if (patrolStart >= patrolEnd) revert CoordsAreNotSorted(PATROL);

        uint8 patrolDiff = patrolEnd - patrolStart;
        uint8 patrolHorizontal = PATROL_LENGTH - 1;
        // required difference between end and start coords of Patrol ship in horizontal orientation
        uint8 patrolVertical = patrolHorizontal * 8;
        // required difference in vertical orientation (because indices wrap around the 8x8 board)
        if (!(patrolDiff == patrolHorizontal || patrolDiff == patrolVertical))
            revert NotRightSizeOrOrientation(PATROL);

        // ------------------------------ DESTROYER1 ship validation ------------------------------
        uint8 destroyer1Start = getCoordsStart(fleet, DESTROYER1);
        uint8 destroyer1End = getCoordsEnd(fleet, DESTROYER1);
        if (destroyer1Start >= destroyer1End)
            revert CoordsAreNotSorted(DESTROYER1);

        uint8 destroyer1Diff = destroyer1End - destroyer1Start;
        uint8 destroyerHorizontal = DESTROYER_LENGTH - 1;
        uint8 destroyerVertical = destroyerHorizontal * 8;
        if (
            !(destroyer1Diff == destroyerHorizontal ||
                destroyer1Diff == destroyerVertical)
        ) revert NotRightSizeOrOrientation(DESTROYER1);

        // ------------------------------ DESTROYER2 ship validation ------------------------------
        uint8 destroyer2Start = getCoordsStart(fleet, DESTROYER2);
        uint8 destroyer2End = getCoordsEnd(fleet, DESTROYER2);
        if (destroyer2Start >= destroyer2End)
            revert CoordsAreNotSorted(DESTROYER2);

        uint8 destroyer2Diff = destroyer2End - destroyer2Start;
        if (
            !(destroyer2Diff == destroyerHorizontal ||
                destroyer2Diff == destroyerVertical)
        ) revert NotRightSizeOrOrientation(DESTROYER2);

        // ------------------------------ BATTLESHIP ship validation ------------------------------
        uint8 battleshipStart = getCoordsStart(fleet, BATTLESHIP);
        uint8 battleshipEnd = getCoordsEnd(fleet, BATTLESHIP);
        if (battleshipStart >= battleshipEnd)
            revert CoordsAreNotSorted(BATTLESHIP);

        uint8 battleshipDiff = battleshipEnd - battleshipStart;
        uint8 battleshipHorizontal = BATTLESHIP_LENGTH - 1;
        uint8 battleshipVertical = battleshipHorizontal * 8;
        if (
            !(battleshipDiff == battleshipHorizontal ||
                battleshipDiff == battleshipVertical)
        ) revert NotRightSizeOrOrientation(BATTLESHIP);

        // ------------------------------ CARRIER ship validation ------------------------------
        uint8 carrierStart = getCoordsStart(fleet, CARRIER);
        uint8 carrierEnd = getCoordsEnd(fleet, CARRIER);
        if (carrierStart >= carrierEnd) revert CoordsAreNotSorted(CARRIER);

        uint8 carrierDiff = carrierEnd - carrierStart;
        uint8 carrierHorizontal = (CARRIER_LENGTH - 1) +
            (8 * (CARRIER_WIDTH - 1)); // carrier size is 4x2
        uint8 carrierVertical = (CARRIER_LENGTH - 1) * 8 + (CARRIER_WIDTH - 1);
        if (
            !(carrierDiff == carrierHorizontal ||
                carrierDiff == carrierVertical)
        ) revert NotRightSizeOrOrientation(CARRIER);

        // ------------------------------ building the board ------------------------------
        // This piece converts the fleet into 8x8 board representation.
        // It also validates that ships don't overlap and that
        // ships are not too close.

        // construct the board from fleet info
        Board.BuildData memory constructedBoard = Board.BuildData(0, 0);
        constructedBoard.placeShip(patrolStart, patrolEnd, PATROL);
        constructedBoard.placeShip(destroyer1Start, destroyer1End, DESTROYER1);
        constructedBoard.placeShip(destroyer2Start, destroyer2End, DESTROYER2);
        constructedBoard.placeShip(carrierStart, carrierEnd, CARRIER);
        constructedBoard.placeShip(battleshipStart, battleshipEnd, BATTLESHIP);
        return constructedBoard.board;
    }
}
