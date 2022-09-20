// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../Game.sol";

// While implementation of this contract does not need to memoize anything in order to be able
// to play correctly (memoized values will be provided as arguments to fire function), only limited
// context will be provided. This contract can store additional info in its own storage that will
// be useful context
interface IGeneral {
    // must be the address (not necessarily EOA) you will be calling the Coordinator contract from.
    // this value is to check that no one else is using your code to play.
    // Credit: 0xBeans
    function owner() external view virtual returns (address);

    // Note: The allCars array comes sorted in descending order of each car's y position.
    // maybe provide out of the box way to infer direction of ship from a hit and destroy it
    function fire(uint256 yourCarIndex) external virtual returns (uint32);
    // TODO parameters are explicitly named like this myBoard, myAttacks, otherAttacks
    // how can a player infer that phase of game? Early phase/exploration or late game where tracking min length or tracking the hit ship
}
