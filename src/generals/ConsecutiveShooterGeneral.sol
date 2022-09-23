// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IGeneral.sol";
import "../utils/Attacks.sol";

contract ConsecutiveShooterGeneral is IGeneral {
    using Attacks for uint192;

    address private _owner;

    constructor() {
        _owner = msg.sender;
    }

    function owner() external view returns (address) {
        return _owner;
    }

    function fire(
        uint256, /* myBoard */
        uint192, /* myAttacks */
        uint192, /* opponentsAttacks */
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
