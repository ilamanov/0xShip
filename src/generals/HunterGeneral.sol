// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IGeneral.sol";
import "../utils/Attacks.sol";

contract HunterGeneral is IGeneral {
    using Attacks for uint256;

    address private _owner;

    constructor() {
        _owner = msg.sender;
    }

    function name() external pure override returns (string memory) {
        return "hunter";
    }

    function owner() external view override returns (address) {
        return _owner;
    }

    function fire(
        uint256, /* myBoard */
        uint256 myAttacks,
        uint256, /* opponentsAttacks */
        uint256 myLastMove,
        uint256 opponentsLastMove,
        uint256 /* opponentsDiscoveredFleet */
    ) external pure override returns (uint256) {
        if (myLastMove == 255 || myAttacks.isOfType(myLastMove, Attacks.MISS)) {
            // myLastMove=255 indicates that game just started

            // use number of empty cells as initial entropy for random cellToFire
            uint256 emptyCells = myAttacks.numberOfEmptyCells();
            uint256 cellToFire;
            do {
                cellToFire =
                    uint256(
                        keccak256(
                            abi.encode(
                                cellToFire,
                                emptyCells,
                                myLastMove,
                                opponentsLastMove
                            )
                        )
                    ) %
                    64;
            } while (!myAttacks.isOfType(cellToFire, Attacks.UNTOUCHED));
            return cellToFire;
        }
        // otherwise it was a hit, so choose an adjacent cell to fire
        int256 y = int256(myLastMove >> 3);
        int256 x = int256(myLastMove % 8);

        int256 cellToFire;
        do {
            uint256 random = uint256(
                keccak256(abi.encode(cellToFire, myLastMove, opponentsLastMove))
            );
            int256 dy = int256(random % 3);
            int256 dx = int256((random >> 2) % 3);
            if (y == 0) {
                dy = dy % 2;
            } else if (y == 7) {
                dy = -(dy % 2);
            } else {
                dy -= 1;
            }
            if (x == 0) {
                dx = dx % 2;
            } else if (x == 7) {
                dx = -(dx % 2);
            } else {
                dx -= 1;
            }

            y += dy;
            x += dx;
            cellToFire = y * 8 + x;
        } while (!myAttacks.isOfType(uint256(cellToFire), Attacks.UNTOUCHED));
        return uint256(cellToFire);
    }
}
