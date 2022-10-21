// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IGeneral.sol";
import "../utils/Attacks.sol";

contract DFSGeneral is IGeneral {
    using Attacks for uint256;

    address private _owner;
    uint256 private previousHits;

    constructor() {
        _owner = msg.sender;
        previousHits = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    }

    function name() external pure override returns (string memory) {
        return "deep";
    }

    function owner() external view override returns (address) {
        return _owner;
    }

    function pickRandom(
        uint256 myAttacks,
        uint256 myLastMove,
        uint256 opponentsLastMove
    ) private pure returns (uint256 cellToFire) {
        // use number of empty cells as initial entropy for random cellToFire
        uint256 emptyCells = myAttacks.numberOfEmptyCells();
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
    }

    function checkNeighbors(uint256 myAttacks, uint256 cellIdx)
        private
        pure
        returns (uint256)
    {
        uint256 y = cellIdx >> 3;
        uint256 x = cellIdx % 8;

        if (y > 0) {
            uint256 candidate = cellIdx - 8;
            if (myAttacks.isOfType(candidate, Attacks.UNTOUCHED)) {
                return candidate;
            }
        }
        if (y < 8) {
            uint256 candidate = cellIdx + 8;
            if (myAttacks.isOfType(candidate, Attacks.UNTOUCHED)) {
                return candidate;
            }
        }
        if (x > 0) {
            uint256 candidate = cellIdx - 1;
            if (myAttacks.isOfType(candidate, Attacks.UNTOUCHED)) {
                return candidate;
            }
        }
        if (x < 8) {
            uint256 candidate = cellIdx + 1;
            if (myAttacks.isOfType(candidate, Attacks.UNTOUCHED)) {
                return candidate;
            }
        }

        return 64;
    }

    function fire(
        uint256, /* myBoard */
        uint256 myAttacks,
        uint256, /* opponentsAttacks */
        uint256 myLastMove,
        uint256 opponentsLastMove,
        uint256 /* opponentsDiscoveredFleet */
    ) external override returns (uint256) {
        uint256 lastHit = 64;
        uint256 previousHitsCached = previousHits;

        if (myLastMove == 255) {
            // myLastMove=255 indicates that game just started
        } else if (myAttacks.isOfType(myLastMove, Attacks.HIT)) {
            previousHits = (previousHitsCached << 8) | uint8(myLastMove);
            lastHit = myLastMove;
        } else {
            uint256 lastStored = previousHitsCached & 0xFF;
            if (lastStored != 0xFF) {
                lastHit = lastStored;
            }
        }

        if (lastHit == 64) {
            return pickRandom(myAttacks, myLastMove, opponentsLastMove);
        }

        // otherwise it was a hit, so choose an adjacent cell to fire
        uint256 i = 0;
        do {
            uint256 cellToFire = checkNeighbors(myAttacks, lastHit);
            if (cellToFire != 64) {
                if (i > 0) {
                    previousHits =
                        (previousHitsCached >> (i * 8)) |
                        ~((1 << (256 - (i * 8))) - 1);
                }
                return cellToFire;
            }
            // if all adjacent have already been visited, then pop lastHit and start with the next
            i++;
            lastHit = (previousHitsCached >> (i * 8)) & 0xFF;
        } while (lastHit != 0xFF);

        previousHits = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        return pickRandom(myAttacks, myLastMove, opponentsLastMove);
    }
}
