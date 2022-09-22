// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IGeneral {
    // must be the address you will be calling the Game contract from.
    // this value is to check that no one else is using your code to play. credit: 0xBeans
    function owner() external view returns (address);

    // this function needs to return an index into the 8x8 board, i.e. a value between [0 and 64).
    // a shell will be fired at this location. if you return >= 64, you're TKO'd
    // you're constrained by gas in this function. Check Game contract for max_gas
    // check Board library for the layout of bits of myBoard
    // check Attacks library for the layout of bits of attacks
    // check Fleet library for the layout of bits of fleet. Non-discovered fleet will have both,
    // the start and end coords =0
    function fire(
        uint192 myBoard,
        uint192 myAttacks,
        uint192 opponentsAttacks,
        uint8 myLastMove,
        uint8 opponentsLastMove,
        uint64 opponentsDiscoveredFleet
    ) external returns (uint8);
}
