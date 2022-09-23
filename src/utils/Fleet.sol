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
    uint256 internal constant PATROL_LENGTH = 2;
    uint256 internal constant DESTROYER_LENGTH = 3;
    uint256 internal constant CARRIER_LENGTH = 4;
    uint256 internal constant CARRIER_WIDTH = 2;
    uint256 internal constant BATTLESHIP_LENGTH = 5;

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

    // This struct is only used to avoid stack too deep errors, use a struct to pack all vars into one var
    // https://medium.com/1milliondevs/compilererror-stack-too-deep-try-removing-local-variables-solved-a6bcecc16231
    struct Coords {
        uint8 start;
        uint8 end;
        uint8 diff;
        uint256 horizontal;
        uint256 vertical;
    }

    // only used in Game.revealBoard to validate the fleet and store the board representation
    // of the fleet for faster lookup
    function validateFleetAndConvertToBoard(uint64 fleet)
        internal
        pure
        returns (uint256)
    {
        // make sure that the fleet is properly formatted: ships have the right size and
        // orientation (either horizontal or vertical)

        // ------------------------------ PATROL ship validation ------------------------------
        Coords memory patrolCoords;
        patrolCoords.start = getCoordsStart(fleet, PATROL);
        patrolCoords.end = getCoordsEnd(fleet, PATROL);
        // start and end are guaranteed to be within [0, 64)
        // because we mask out the leading bits in getCoords[X]
        if (patrolCoords.start >= patrolCoords.end)
            revert CoordsAreNotSorted(PATROL);

        patrolCoords.diff = patrolCoords.end - patrolCoords.start;
        patrolCoords.horizontal = PATROL_LENGTH - 1;
        // required difference between end and start coords of Patrol ship in horizontal orientation
        patrolCoords.vertical = patrolCoords.horizontal * 8;
        // required difference in vertical orientation (because indices wrap around the 8x8 board)
        if (
            !(patrolCoords.diff == patrolCoords.horizontal ||
                patrolCoords.diff == patrolCoords.vertical)
        ) revert NotRightSizeOrOrientation(PATROL);

        // ------------------------------ DESTROYER1 ship validation ------------------------------
        Coords memory destroyer1Coords;
        destroyer1Coords.start = getCoordsStart(fleet, DESTROYER1);
        destroyer1Coords.end = getCoordsEnd(fleet, DESTROYER1);
        if (destroyer1Coords.start >= destroyer1Coords.end)
            revert CoordsAreNotSorted(DESTROYER1);

        destroyer1Coords.diff = destroyer1Coords.end - destroyer1Coords.start;
        destroyer1Coords.horizontal = DESTROYER_LENGTH - 1;
        destroyer1Coords.vertical = destroyer1Coords.horizontal * 8;
        if (
            !(destroyer1Coords.diff == destroyer1Coords.horizontal ||
                destroyer1Coords.diff == destroyer1Coords.vertical)
        ) revert NotRightSizeOrOrientation(DESTROYER1);

        // ------------------------------ DESTROYER2 ship validation ------------------------------
        Coords memory destroyer2Coords;
        destroyer2Coords.start = getCoordsStart(fleet, DESTROYER2);
        destroyer2Coords.end = getCoordsEnd(fleet, DESTROYER2);
        if (destroyer2Coords.start >= destroyer2Coords.end)
            revert CoordsAreNotSorted(DESTROYER2);

        destroyer2Coords.diff = destroyer2Coords.end - destroyer2Coords.start;
        if (
            !(destroyer2Coords.diff == destroyer1Coords.horizontal ||
                destroyer2Coords.diff == destroyer1Coords.vertical)
        ) revert NotRightSizeOrOrientation(DESTROYER2);

        // ------------------------------ BATTLESHIP ship validation ------------------------------
        Coords memory battleshipCoords;
        battleshipCoords.start = getCoordsStart(fleet, BATTLESHIP);
        battleshipCoords.end = getCoordsEnd(fleet, BATTLESHIP);
        if (battleshipCoords.start >= battleshipCoords.end)
            revert CoordsAreNotSorted(BATTLESHIP);

        battleshipCoords.diff = battleshipCoords.end - battleshipCoords.start;
        battleshipCoords.horizontal = BATTLESHIP_LENGTH - 1;
        battleshipCoords.vertical = battleshipCoords.horizontal * 8;
        if (
            !(battleshipCoords.diff == battleshipCoords.horizontal ||
                battleshipCoords.diff == battleshipCoords.vertical)
        ) revert NotRightSizeOrOrientation(BATTLESHIP);

        // ------------------------------ CARRIER ship validation ------------------------------
        Coords memory carrierCoords;
        carrierCoords.start = getCoordsStart(fleet, CARRIER);
        carrierCoords.end = getCoordsEnd(fleet, CARRIER);
        if (carrierCoords.start >= carrierCoords.end)
            revert CoordsAreNotSorted(CARRIER);

        carrierCoords.diff = carrierCoords.end - carrierCoords.start;
        carrierCoords.horizontal =
            (CARRIER_LENGTH - 1) +
            (8 * (CARRIER_WIDTH - 1)); // carrier size is 4x2
        carrierCoords.vertical = (CARRIER_LENGTH - 1) * 8 + (CARRIER_WIDTH - 1);
        if (
            !(carrierCoords.diff == carrierCoords.horizontal ||
                carrierCoords.diff == carrierCoords.vertical)
        ) revert NotRightSizeOrOrientation(CARRIER);

        // ------------------------------ building the board ------------------------------
        // This piece converts the fleet into 8x8 board representation.
        // It also validates that ships don't overlap and that
        // ships are not too close.

        // construct the board from fleet info
        Board.BuildData memory constructedBoard = Board.BuildData(0, 0);
        constructedBoard.placeShip(
            patrolCoords.start,
            patrolCoords.end,
            PATROL
        );
        constructedBoard.placeShip(
            destroyer1Coords.start,
            destroyer1Coords.end,
            DESTROYER1
        );
        constructedBoard.placeShip(
            destroyer2Coords.start,
            destroyer2Coords.end,
            DESTROYER2
        );
        constructedBoard.placeShip(
            carrierCoords.start,
            carrierCoords.end,
            CARRIER
        );
        constructedBoard.placeShip(
            battleshipCoords.start,
            battleshipCoords.end,
            BATTLESHIP
        );
        return constructedBoard.board;
    }
}
