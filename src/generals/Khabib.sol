// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IGeneral.sol";
import "../utils/Attacks.sol";

// TODO check for remaining ship size early return
// TODO instead of shooting randomly, check where a ship can actually fit
// TODO early stopping based on if newly destroyed or not. Cache num of destroyed in context
contract Khabib is IGeneral {
    using Attacks for uint256;

    address private _owner;

    constructor() {
        _owner = msg.sender;
    }

    function name() external pure override returns (string memory) {
        return "khabib";
    }

    function owner() external view override returns (address) {
        return _owner;
    }

    // Thanks a lot recmo@ ! https://xn--2-umb.com/22/exp-ln/
    // Compute the discrete binary logarithm of x using 191 gas.
    // Requires x to be non-zero
    function log2(uint256 x) internal pure returns (uint256 r) {
        assembly {
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))

            // For the remaining 32 bits, use a De Bruijn lookup.
            x := shr(r, x)
            x := or(x, shr(1, x))
            x := or(x, shr(2, x))
            x := or(x, shr(4, x))
            x := or(x, shr(8, x))
            x := or(x, shr(16, x))
            r := or(
                r,
                byte(
                    shr(251, mul(x, shl(224, 0x07c4acdd))),
                    0x0009010a0d15021d0b0e10121619031e080c141c0f111807131b17061a05041f
                )
            )
        }
    }

    function pickRandom(
        uint256 myAttacks,
        uint256 myLastMove,
        uint256 opponentsLastMove
    ) private pure returns (uint256 cellToFire) {
        // use number of empty cells as initial entropy for random cellToFire
        uint256 emptyCells = myAttacks.numberOfEmptyCells();
        uint256 i = 0;
        do {
            cellToFire =
                uint256(
                    keccak256(
                        abi.encode(
                            cellToFire,
                            i,
                            emptyCells,
                            myLastMove,
                            opponentsLastMove
                        )
                    )
                ) %
                64;
            i++;
        } while (!myAttacks.isOfType(cellToFire, Attacks.UNTOUCHED));

        // // get position of righmost 1 in "untouched" array
        // uint256 pos = myAttacks & ~(myAttacks - 1);
        // return log2(pos);
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
            direction = (data >> 6) & 7;
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
        if (getDirection(firstHit, myActualLastMove) != oppositeDirection) {
            uint256 cellToFire = checkDirection(
                firstHit,
                oppositeDirection,
                myAttacks
            );

            if (cellToFire != 64) {
                return (data << 6) | cellToFire;
            }
        } else {
            if (myAttacks.isOfType(myActualLastMove, Attacks.HIT)) {
                uint256 cellToFire = checkDirection(
                    myActualLastMove,
                    oppositeDirection,
                    myAttacks
                );

                if (cellToFire != 64) {
                    return (data << 6) | cellToFire;
                }
            }
        }

        // data = 0;
        return pickRandom(myAttacks, myActualLastMove, opponentsLastMove);
    }
}
