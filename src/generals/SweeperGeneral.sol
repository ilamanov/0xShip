// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IGeneral.sol";

contract SweeperGeneral is IGeneral {
    address private _owner;

    constructor() {
        _owner = msg.sender;
    }

    function name() external pure override returns (string memory) {
        return "sweeper";
    }

    function owner() external view override returns (address) {
        return _owner;
    }

    function fire(
        uint256, /* myBoard */
        uint256, /* myAttacks */
        uint256, /* opponentsAttacks */
        uint256 myLastMove,
        uint256, /* opponentsLastMove */
        uint256 /* opponentsDiscoveredFleet */
    ) external pure override returns (uint256) {
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
