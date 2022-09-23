// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Board.sol";

error CoordsAreNotSorted(uint256 shipType);
error NotRightSizeOrOrientation(uint256 shipType);

/**
 * Board is represented using 256 bits, but only rightmost 64 bits are used. Bit layout of the 64 bits:
 * [4 empty bits | battleship start coord | battleship end coord | carrier start coord | ... | patrol end coord]
 * Each coord is 6 bits and it's an index into the 8x8 board, i.e. [0, 64)
 */
library Fleet {
    // initializer for undiscovered fleet
    uint256 internal constant EMPTY_FLEET = 0;

    // ship types
    uint256 internal constant EMPTY = 0;
    uint256 internal constant PATROL = 1;
    uint256 internal constant DESTROYER1 = 2;
    uint256 internal constant DESTROYER2 = 3;
    uint256 internal constant CARRIER = 4;
    uint256 internal constant BATTLESHIP = 5;

    // ship sizes
    uint256 internal constant PATROL_LENGTH = 2;
    uint256 internal constant DESTROYER_LENGTH = 3;
    uint256 internal constant CARRIER_LENGTH = 4;
    uint256 internal constant CARRIER_WIDTH = 2;
    uint256 internal constant BATTLESHIP_LENGTH = 5;

    function getCoords(uint256 fleet, uint256 shipType)
        internal
        pure
        returns (uint256)
    {
        // each ship takes up 2*6=12 bits. Need to shift right by
        // correct number of bits and take only the remaining 12 bits (0xFFF is 12 ones)
        return (fleet >> (12 * (shipType - 1))) & 0xFFF;
    }

    // populate toFleet with the coords of shipType from fromFleet
    function copyShipTo(
        uint256 fromFleet,
        uint256 toFleet,
        uint256 shipType
    ) internal pure returns (uint256) {
        uint256 selectShip = 0xFFF << (shipType - 1); // 0xFFF is 12 ones
        return (fromFleet & selectShip) | (toFleet & ~selectShip);
    }

    using Board for Board.BuildData;

    // This struct is only used to avoid stack too deep errors, use a struct to pack all vars into one var
    // https://medium.com/1milliondevs/compilererror-stack-too-deep-try-removing-local-variables-solved-a6bcecc16231
    struct Coords {
        uint256 start;
        uint256 end;
        uint256 diff;
        uint256 horizontal;
        uint256 vertical;
    }

    // only used in Game.revealBoard to validate the fleet and store the board representation
    // of the fleet for faster lookup
    function validateFleetAndConvertToBoard(uint256 fleet)
        internal
        pure
        returns (uint256)
    {
        // make sure that the fleet is properly formatted: ships have the right size and
        // orientation (either horizontal or vertical)

        // ------------------------------ PATROL ship validation ------------------------------
        Coords memory patrolCoords;
        uint256 tmpCoords = getCoords(fleet, PATROL);
        patrolCoords.start = tmpCoords >> 6;
        patrolCoords.end = tmpCoords & 0x3F;
        // start and end are guaranteed to be within [0, 64)
        // because we mask out the leading bits in getCoords[X]
        if (patrolCoords.start >= patrolCoords.end)
            revert CoordsAreNotSorted(PATROL);

        patrolCoords.diff = patrolCoords.end - patrolCoords.start;
        patrolCoords.horizontal = PATROL_LENGTH - 1;
        // required difference between end and start coords of Patrol ship in horizontal orientation
        patrolCoords.vertical = patrolCoords.horizontal << 3; // "<< 3" is same as "* 8"
        // required difference in vertical orientation (because indices wrap around the 8x8 board)
        if (
            !(patrolCoords.diff == patrolCoords.horizontal ||
                patrolCoords.diff == patrolCoords.vertical)
        ) revert NotRightSizeOrOrientation(PATROL);

        // ------------------------------ DESTROYER1 ship validation ------------------------------
        Coords memory destroyer1Coords;
        tmpCoords = getCoords(fleet, DESTROYER1);
        destroyer1Coords.start = tmpCoords >> 6;
        destroyer1Coords.end = tmpCoords & 0x3F;
        if (destroyer1Coords.start >= destroyer1Coords.end)
            revert CoordsAreNotSorted(DESTROYER1);

        destroyer1Coords.diff = destroyer1Coords.end - destroyer1Coords.start;
        destroyer1Coords.horizontal = DESTROYER_LENGTH - 1;
        destroyer1Coords.vertical = destroyer1Coords.horizontal << 3;
        if (
            !(destroyer1Coords.diff == destroyer1Coords.horizontal ||
                destroyer1Coords.diff == destroyer1Coords.vertical)
        ) revert NotRightSizeOrOrientation(DESTROYER1);

        // ------------------------------ DESTROYER2 ship validation ------------------------------
        Coords memory destroyer2Coords;
        tmpCoords = getCoords(fleet, DESTROYER2);
        destroyer2Coords.start = tmpCoords >> 6;
        destroyer2Coords.end = tmpCoords & 0x3F;
        if (destroyer2Coords.start >= destroyer2Coords.end)
            revert CoordsAreNotSorted(DESTROYER2);

        destroyer2Coords.diff = destroyer2Coords.end - destroyer2Coords.start;
        if (
            !(destroyer2Coords.diff == destroyer1Coords.horizontal ||
                destroyer2Coords.diff == destroyer1Coords.vertical)
        ) revert NotRightSizeOrOrientation(DESTROYER2);

        // ------------------------------ BATTLESHIP ship validation ------------------------------
        Coords memory battleshipCoords;
        tmpCoords = getCoords(fleet, BATTLESHIP);
        battleshipCoords.start = tmpCoords >> 6;
        battleshipCoords.end = tmpCoords & 0x3F;
        if (battleshipCoords.start >= battleshipCoords.end)
            revert CoordsAreNotSorted(BATTLESHIP);

        battleshipCoords.diff = battleshipCoords.end - battleshipCoords.start;
        battleshipCoords.horizontal = BATTLESHIP_LENGTH - 1;
        battleshipCoords.vertical = battleshipCoords.horizontal << 3;
        if (
            !(battleshipCoords.diff == battleshipCoords.horizontal ||
                battleshipCoords.diff == battleshipCoords.vertical)
        ) revert NotRightSizeOrOrientation(BATTLESHIP);

        // ------------------------------ CARRIER ship validation ------------------------------
        Coords memory carrierCoords;
        tmpCoords = getCoords(fleet, CARRIER);
        carrierCoords.start = tmpCoords >> 6;
        carrierCoords.end = tmpCoords & 0x3F;
        if (carrierCoords.start >= carrierCoords.end)
            revert CoordsAreNotSorted(CARRIER);

        carrierCoords.diff = carrierCoords.end - carrierCoords.start;
        carrierCoords.horizontal =
            (CARRIER_LENGTH - 1) +
            ((CARRIER_WIDTH - 1) << 3); // carrier size is 4x2
        carrierCoords.vertical =
            ((CARRIER_LENGTH - 1) << 3) +
            (CARRIER_WIDTH - 1);
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
