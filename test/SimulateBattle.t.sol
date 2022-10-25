// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Game.sol";
import "../src/generals/IGeneral.sol";
import "../src/generals/RandomGeneral.sol";
import "../src/generals/SweeperGeneral.sol";
import "../src/generals/HunterGeneral.sol";
import "../src/generals/DFSGeneral.sol";
import "../src/generals/TrackerGeneral.sol";
import "../src/utils/Fleet.sol";

contract SimulateBattle is Test {
    using Fleet for uint256;

    uint256 private constant FLEET1 = 56122492264271099; // TODO paste your fleet value
    uint256 private constant FLEET2 = 294004535682387455; // TODO paste your fleet value

    bytes32 private constant SALT1 = "2";
    bytes32 private constant SALT2 = "5";

    Game public game;
    IGeneral general1;
    IGeneral general2;

    function setUp() public {
        game = new Game();

        general1 = new SweeperGeneral(); // TODO choose your general. I like to keep this as SweeperGeneral because it makes it easier to trace the moves during debugging (since Sweeper just outputs consecuitve cells)
        general2 = new TrackerGeneral(); // TODO choose your general

        Game.Gear memory gear1 = Game.Gear(
            general1,
            _getFleetHash(FLEET1, SALT1)
        );
        Game.Gear memory gear2 = Game.Gear(
            general2,
            _getFleetHash(FLEET2, SALT2)
        );

        game.submitChallenge(gear1, 0, general2);
        game.acceptChallenge(
            gear2,
            keccak256(abi.encodePacked(general1, _getFleetHash(FLEET1, SALT1)))
        );
    }

    function testBattle() public {
        game.revealFleetsAndStartBattle(
            _getFleetHash(FLEET1, SALT1),
            FLEET1,
            SALT1,
            _getFleetHash(FLEET2, SALT2),
            FLEET2,
            SALT2,
            keccak256(abi.encodePacked(general1, _getFleetHash(FLEET1, SALT1))),
            0,
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
