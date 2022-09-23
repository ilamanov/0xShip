// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Game.sol";
import "../src/generals/IGeneral.sol";
import "../src/generals/RandomShooterGeneral.sol";
import "../src/generals/ConsecutiveShooterGeneral.sol";
import "../src/utils/Fleet.sol";

contract BattleTest is Test {
    using Fleet for uint256;

    // fleet1
    // 4 4 4 4 0 0 0 1
    // 4 4 4 4 0 0 0 1
    // 0 0 0 0 0 2 0 0
    // 0 3 0 0 0 2 0 0
    // 0 3 0 0 0 2 0 0
    // 0 3 0 0 0 0 0 0
    // 0 0 0 0 0 0 0 0
    // 5 5 5 5 5 0 0 0
    //
    // 0000 | 56 | 60 | 0 | 11 | 25 | 41 | 21 | 37 | 7 | 15
    // 0000 | 111000 | 111100 | 000000 | 001011 | 011001 | 101001 | 010101 | 100101 | 000111 | 001111
    //
    uint256 private constant FLEET1 = 0xE3C00B6695651CF;
    bytes32 private constant SALT1 = "2";

    // fleet2
    // 0 0 0 0 0 0 0 0
    // 0 0 0 0 0 0 0 0
    // 2 0 0 5 5 5 5 5
    // 2 0 0 0 0 0 0 0
    // 2 0 0 0 0 1 0 0
    // 0 0 0 0 0 1 0 3
    // 4 4 4 4 0 0 0 3
    // 4 4 4 4 0 0 0 3
    //
    // 0000 | 19 | 23 | 48 | 59 | 47 | 63 | 16 | 32 | 37 | 45
    // 0000 | 010011 | 010111 | 110000 | 111011 | 101111 | 111111 | 010000 | 100000 | 100101 | 101101
    //
    uint256 private constant FLEET2 = 0x4D7C3BBFF42096D;
    bytes32 private constant SALT2 = "5";

    Game public game;
    IGeneral general1;
    IGeneral general2;

    function setUp() public {
        game = new Game();
        general1 = new RandomShooterGeneral();
        general2 = new ConsecutiveShooterGeneral();
        _submitChallenge();
        _acceptChallenge();
    }

    function testBattle() public {
        _startBattle();
    }

    function _submitChallenge() private {
        game.submitChallenge(
            Game.Gear(general1, _getFleetHash(FLEET1, SALT1)),
            500,
            general2
        );
    }

    function _acceptChallenge() private {
        game.acceptChallenge(
            Game.Gear(general2, _getFleetHash(FLEET2, SALT2)),
            keccak256(abi.encodePacked(general1, _getFleetHash(FLEET1, SALT1)))
        );
    }

    function _startBattle() private {
        game.revealFleetsAndStartBattle(
            _getFleetHash(FLEET1, SALT1),
            FLEET1,
            SALT1,
            _getFleetHash(FLEET2, SALT2),
            FLEET2,
            SALT2,
            keccak256(abi.encodePacked(general1, _getFleetHash(FLEET1, SALT1))),
            128,
            address(this)
        );
    }

    function _getFleetHash(uint256 fleet, bytes32 salt)
        private
        pure
        returns (uint96)
    {
        return uint96(uint256(keccak256(abi.encodePacked(fleet, salt))));
    }
}
