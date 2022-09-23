// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Game.sol";
import "../src/generals/IGeneral.sol";
import "../src/generals/RandomShooterGeneral.sol";
import "../src/utils/Fleet.sol";
import "../src/utils/Board.sol";

contract GameTest is Test {
    using Fleet for uint256;
    using Board for uint256;

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
        general2 = new RandomShooterGeneral();
    }

    function testSubmitChallenge() public {
        _submitChallenge();
        Game.Challenge[] memory challenges = game.getAllChallenges();
        assertEq(challenges.length, 1);
        assertEq(address(challenges[0].challenger.general), address(general1));
        assertEq(
            challenges[0].challenger.fleetHash,
            _getFleetHash(FLEET1, SALT1)
        );
        assertEq(challenges[0].bidAmount, 0);
        assertEq(challenges[0].facilitatorPercentage, 500);
        assertEq(address(challenges[0].preferredOpponent), address(general2));
    }

    function testAcceptChallenge() public {
        _submitChallenge();
        _acceptChallenge();
        Game.Challenge[] memory challenges = game.getAllChallenges();
        assertEq(challenges.length, 1);

        assertEq(address(challenges[0].challenger.general), address(general1));
        assertEq(
            challenges[0].challenger.fleetHash,
            _getFleetHash(FLEET1, SALT1)
        );

        assertEq(address(challenges[0].caller.general), address(general2));
        assertEq(challenges[0].caller.fleetHash, _getFleetHash(FLEET2, SALT2));

        assertEq(challenges[0].bidAmount, 0);
        assertEq(challenges[0].facilitatorPercentage, 500);
        assertEq(address(challenges[0].preferredOpponent), address(general2));
    }

    function testRevealFleet() public {
        _submitChallenge();
        _acceptChallenge();
        // 7 | 15 | 21 | 37 | 25 | 41 | 0 | 11 | 56 | 60
        _assertCoords(FLEET1, Fleet.PATROL, 7, 15);
        _assertCoords(FLEET1, Fleet.DESTROYER1, 21, 37);
        _assertCoords(FLEET1, Fleet.DESTROYER2, 25, 41);
        _assertCoords(FLEET1, Fleet.CARRIER, 0, 11);
        _assertCoords(FLEET1, Fleet.BATTLESHIP, 56, 60);
        _revealFleet();
        Game.Challenge[] memory challenges = game.getAllChallenges();
        assertEq(challenges.length, 1);

        uint256 fleet;
        uint256 board;
        {
            (uint64 fleetTmp, uint192 boardTmp) = game.fleetsAndBoards(
                challenges[0].challenger.fleetHash
            );
            fleet = uint256(fleetTmp);
            board = uint256(boardTmp);
        }

        assertEq(fleet, FLEET1);
        uint8[8][8] memory manualBoard = [
            [4, 4, 4, 4, 0, 0, 0, 1],
            [4, 4, 4, 4, 0, 0, 0, 1],
            [0, 0, 0, 0, 0, 2, 0, 0],
            [0, 3, 0, 0, 0, 2, 0, 0],
            [0, 3, 0, 0, 0, 2, 0, 0],
            [0, 3, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [5, 5, 5, 5, 5, 0, 0, 0]
        ];
        for (uint256 y = 0; y < 8; y++) {
            for (uint256 x = 0; x < 8; x++) {
                assertEq(board.getShipAt(y * 8 + x), manualBoard[y][x]);
            }
        }
        // TODO test overlaps including the adjacency
    }

    function _assertCoords(
        uint256 fleet,
        uint256 shipType,
        uint256 startCoord,
        uint256 endCoord
    ) private {
        uint256 coords = fleet.getCoords(shipType);
        assertEq(coords >> 6, startCoord);
        assertEq(coords & 0x3F, endCoord);
    }

    function testBattle() public {
        _submitChallenge();
        _acceptChallenge();
        _revealFleet();
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

    function _revealFleet() private {
        game.revealFleet(_getFleetHash(FLEET1, SALT1), FLEET1, SALT1);
        game.revealFleet(_getFleetHash(FLEET2, SALT2), FLEET2, SALT2);
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
