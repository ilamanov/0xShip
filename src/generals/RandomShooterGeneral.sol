// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IGeneral.sol";
import "../utils/Attacks.sol";

contract RandomShooterGeneral is IGeneral {
    using Attacks for uint192;

    address private _owner;

    constructor() {
        _owner = msg.sender;
    }

    function owner() external view returns (address) {
        return _owner;
    }

    function fire(
        uint192, /* myBoard */
        uint192 myAttacks,
        uint192, /* opponentsAttacks */
        uint256 myLastMove,
        uint256 opponentsLastMove,
        uint64 /* opponentsDiscoveredFleet */
    ) external pure returns (uint256) {
        // use number of empty cells as initial entropy for random cellToFire
        uint8 emptyCells = myAttacks.numberOfEmptyCells();
        uint256 cellToFire = uint256(
            keccak256(abi.encode(emptyCells, myLastMove, opponentsLastMove))
        ) % 64;

        // if you want to avoid duplicates then uncomment next code, but it will run out of gas most of the time
        // while (!myAttacks.isOfType(Attacks.EMPTY, cellToFire)) {
        //     cellToFire =
        //         uint8(
        //             uint256(
        //                 keccak256(
        //                     abi.encode(
        //                         cellToFire,
        //                         opponentsLastMove,
        //                         emptyCells
        //                     )
        //                 )
        //             )
        //         ) %
        //         64;
        // }
        return cellToFire;
    }
}
