// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IGeneral.sol";
import "../utils/Attacks.sol";

// TODO check for remaining ship size early return
// TODO instead of shooting randomly, check where a ship can actually fit
// TODO early stopping based on if newly destroyed or not. Cache num of destroyed in context
contract TrackerGeneral is IGeneral {
    using Attacks for uint256;

    address private _owner;

    constructor() {
        _owner = msg.sender;
    }

    function name() external pure override returns (string memory) {
        return "snake";
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

    function getDirection(uint256 firstHit, uint256 myLastMove)
        private
        pure
        returns (uint256)
    {
        uint256 firstHitY = firstHit >> 3;
        uint256 firstHitX = firstHit % 8;

        uint256 myLastMoveY = myLastMove >> 3;
        uint256 myLastMoveX = myLastMove % 8;

        if (firstHitY == myLastMoveY) {
            if (myLastMoveX > firstHitX) return 1;
            else return 3;
        } else {
            if (myLastMoveY > firstHitY) return 2;
            else return 4;
        }
    }

    function getOppositeDirection(uint256 direction)
        private
        pure
        returns (uint256)
    {
        if (direction == 1) return 3;
        if (direction == 2) return 4;
        if (direction == 3) return 1;
        return 2;
    }

    function checkDirection(
        uint256 cellIdx,
        uint256 direction,
        uint256 myAttacks
    ) private pure returns (uint256) {
        // should check for boundary and for misses
        uint256 y = cellIdx >> 3;
        uint256 x = cellIdx % 8;
        if (direction == 1) {
            if (x == 7) return 64;
            x++;
        } else if (direction == 2) {
            if (y == 7) return 64;
            y++;
        } else if (direction == 3) {
            if (x == 0) return 64;
            x--;
        } else if (direction == 4) {
            if (y == 0) return 64;
            y--;
        }
        uint256 cellToFire = (y << 3) + x;
        if (myAttacks.isOfType(cellToFire, Attacks.UNTOUCHED))
            return cellToFire;
        return 64;
    }

    function fire(
        uint256, /* myBoard */
        uint256 myAttacks,
        uint256, /* opponentsAttacks */
        uint256 myLastMove,
        uint256 opponentsLastMove,
        uint256 /* opponentsDiscoveredFleet */
    ) external pure override returns (uint256) {
        if (myLastMove == 255) {
            return pickRandom(myAttacks, myLastMove, opponentsLastMove);
        }

        uint256 data = myLastMove >> 6;

        // if first point has not been yet found
        if (data == 0) {
            if (myAttacks.isOfType(myLastMove, Attacks.MISS)) {
                return pickRandom(myAttacks, myLastMove, opponentsLastMove);
            }
            return (myLastMove << 6) | checkNeighbors(myAttacks, myLastMove);
        }

        uint256 myActualLastMove = myLastMove & 63;
        uint256 firstHit = data & 63;

        // if direction has not yet been found
        uint256 direction;
        bool firstTime = false;
        if ((data >> 6) == 0) {
            if (myAttacks.isOfType(myActualLastMove, Attacks.MISS)) {
                return (data << 6) | checkNeighbors(myAttacks, firstHit);
            }
            direction = getDirection(firstHit, myActualLastMove);
            data = data | (direction << 6);
            firstTime = true;
        } else {
            direction = (data >> 6) & 3;
        }

        if (
            firstTime ||
            (getDirection(firstHit, myActualLastMove) == direction &&
                myAttacks.isOfType(myActualLastMove, Attacks.HIT))
        ) {
            uint256 cellToFire = checkDirection(
                myActualLastMove,
                direction,
                myAttacks
            );
            if (cellToFire != 64) {
                return (data << 6) | cellToFire;
            }
        }

        uint256 oppositeDirection = getOppositeDirection(direction);
        if (
            getDirection(firstHit, myActualLastMove) == oppositeDirection &&
            myAttacks.isOfType(myActualLastMove, Attacks.MISS)
        ) {
            return
                (data << 6) |
                pickRandom(myAttacks, myActualLastMove, opponentsLastMove);
        }

        uint256 cellToFire = checkDirection(
            firstHit,
            getOppositeDirection(direction),
            myAttacks
        );
        if (cellToFire != 64) {
            return (data << 6) | cellToFire;
        }

        data = 0;
        return
            (data << 6) |
            pickRandom(myAttacks, myActualLastMove, opponentsLastMove);
    }
}
