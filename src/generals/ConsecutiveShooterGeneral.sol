// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IGeneral.sol";

contract ConsecutiveShooterGeneral is IGeneral {
    address private _owner;

    constructor() {
        _owner = msg.sender;
    }

    function owner() external view returns (address) {
        return _owner;
    }

    function fire(
        uint256, /* myBoard */
        uint256, /* myAttacks */
        uint256, /* opponentsAttacks */
        uint256 myLastMove,
        uint256, /* opponentsLastMove */
        uint64 /* opponentsDiscoveredFleet */
    ) external pure returns (uint256) {
        if (myLastMove == 255) {
            // game just started
            return 0;
        }
        if (myLastMove == 63) {
            return 63;
        }
        return myLastMove + 1;
    }
}
