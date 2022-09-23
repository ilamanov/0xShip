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
    // 0000 | 7 | 15 | 21 | 37 | 25 | 41 | 0 | 11 | 56 | 60
    // 0000 | 000111 | 001111 | 010101 | 100101 | 011001 | 101001 | 000000 | 001011 | 111000 | 111100
    uint256 private constant FLEET1 = 0x01CF56566900BE3C;
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
    // 0000 | 37 | 45 | 16 | 32 | 47 | 63 | 48 | 59 | 19 | 23
    // 0000 | 100101 | 101101 | 010000 | 100000 | 101111 | 111111 | 110000 | 111011 | 010011 | 010111
    //
    uint256 private constant FLEET2 = 0x096D420BFFC3B4D7;
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
        assertEq(FLEET1.getCoordsStart(Fleet.PATROL), 7);
        assertEq(FLEET1.getCoordsEnd(Fleet.PATROL), 15);
        assertEq(FLEET1.getCoordsStart(Fleet.DESTROYER1), 21);
        assertEq(FLEET1.getCoordsEnd(Fleet.DESTROYER1), 37);
        assertEq(FLEET1.getCoordsStart(Fleet.DESTROYER2), 25);
        assertEq(FLEET1.getCoordsEnd(Fleet.DESTROYER2), 41);
        assertEq(FLEET1.getCoordsStart(Fleet.CARRIER), 0);
        assertEq(FLEET1.getCoordsEnd(Fleet.CARRIER), 11);
        assertEq(FLEET1.getCoordsStart(Fleet.BATTLESHIP), 56);
        assertEq(FLEET1.getCoordsEnd(Fleet.BATTLESHIP), 60);
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
