// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./generals/IGeneral.sol";
import "./utils/Attacks.sol";
import "./utils/Fleet.sol";
import "./utils/Board.sol";

error NotYourGeneral();
error ChallengeAldreadyExists();
error ChallengeAldreadyLocked();
error ChallengeNeedsToBeLocked();
error FleetsNeedToHaveBeenRevealed();
error ChallengerDoesNotWantToPlayAgainstYou();
error FaciliatorPercentageUnitsWrong();
error NotEnoughEth();
error InvalidFleetHash();
error InvalidMaxTurns();

/**
 * @title 0xShip: On-Chain Battleship Game
 * @author Nazar Ilamanov <@nazar_ilamanov>
 * @dev Here is how the game works at a high level:
 * A challenger submits a Challenge. Challenge consists of the Gear used by the challenger.
 * Gear consists of general (the contract that has playing logic) and the fleet.
 * Anyone can then then accept this challenge. (To accept the challenge you need to provide
 * your own Gear). Accepting the challenge locks a battle between the challenger and the caller.
 * At this point, nothing can be modified about the game. Next step is to reveal your fleet and
 * start the battle. Both of these operations can be performed by a 3rd party facilitator
 * that will be compensated by a percentage of game bid. (Fleet reveal is necessary because
 * fleet is obfuscated initially by providing only the hash of the fleet. This is so that
 * opponents don't know each other's fleet before the battle begins).
 */
contract Game {
    struct Challenge {
        Gear challenger; // initiator of the challenge
        Gear caller; // acceptor of the challenge
        // The rest is optional
        uint256 bidAmount; // can be 0 if not bidding any ETH
        uint96 facilitatorPercentage; // percentage of the bid rewarded for calling startBattle
        IGeneral preferredOpponent; // set by the challenger. If non-zero, then only preferredOpponent can accept the challenge
    }

    // gear brought to the game
    struct Gear {
        IGeneral general; // the general that contains the playing logic
        uint96 fleetHash; // hash of the fleet
        // hash is necessary so that players don't know each other fleet.
        // see revealFleet to understand how hash is computed.
        // using 96 bits for the hash so that entire struct is one word.
    }

    // challengeHash to Challenge
    mapping(bytes32 => Challenge) private challenges;
    // all challengeHashes
    bytes32[] private challengeHashes;

    function getAllChallenges()
        external
        view
        returns (Challenge[] memory allChallenges)
    {
        allChallenges = new Challenge[](challengeHashes.length);
        for (uint256 i = 0; i < allChallenges.length; i++) {
            allChallenges[i] = challenges[challengeHashes[i]];
        }
    }

    function _hashChallenge(Gear calldata challengerGear)
        private
        pure
        returns (bytes32)
    {
        // challenger's gear is hashed as a way to "lock" the selected general and fleetHash.
        // although, the internal logic of the general can still be modified
        return
            keccak256(
                abi.encodePacked(
                    challengerGear.general,
                    challengerGear.fleetHash
                )
            );
    }

    modifier onlyOwnerOfGeneral(IGeneral general) {
        // TODO is there a reentrancy attack possible because calling general.owner? probably don't provide pointer to Coordinator contract (and not only that but also explicitly guard against reentrancy because they can hardcode contract address)
        // check so players dont use other ppls code. Credit: 0xBeans
        if (general.owner() != msg.sender) revert NotYourGeneral();
        _;
    }

    // constant to scale uints into percentages (1e4 == 100%)
    uint96 private constant PERCENTAGE_SCALE = 1e4;

    event ChallengeSubmitted(
        bytes32 indexed challengeHash,
        uint256 indexed bidAmount,
        address indexed general,
        uint96 fleetHash,
        uint96 facilitatorPercentage,
        address preferredOpponent,
        address by
    );

    function submitChallenge(
        Gear calldata gear,
        uint96 facilitatorPercentage,
        IGeneral preferredOpponent
    ) external payable onlyOwnerOfGeneral(gear.general) {
        bytes32 challengeHash = _hashChallenge(gear);
        if (address(challenges[challengeHash].challenger.general) != address(0))
            revert ChallengeAldreadyExists();
        if (facilitatorPercentage > PERCENTAGE_SCALE)
            revert FaciliatorPercentageUnitsWrong();

        challenges[challengeHash].challenger = gear;
        challenges[challengeHash].bidAmount = msg.value;
        challenges[challengeHash].facilitatorPercentage = facilitatorPercentage;
        // if preferredOpponent is zero, then anyone can accept the challenge
        challenges[challengeHash].preferredOpponent = preferredOpponent;
        challengeHashes.push(challengeHash);

        emit ChallengeSubmitted(
            challengeHash,
            msg.value,
            address(gear.general),
            gear.fleetHash,
            facilitatorPercentage,
            address(preferredOpponent),
            msg.sender
        );
    }

    event ChallengeAccepted(
        bytes32 indexed challengeHash,
        address indexed general,
        uint96 fleetHash,
        address by
    );

    function acceptChallenge(Gear calldata gear, bytes32 challengeHash)
        external
        payable
        onlyOwnerOfGeneral(gear.general)
    {
        IGeneral preferredOpponent = challenges[challengeHash]
            .preferredOpponent;
        if (
            address(preferredOpponent) != address(0) &&
            preferredOpponent != gear.general
        ) revert ChallengerDoesNotWantToPlayAgainstYou();

        if (msg.value < challenges[challengeHash].bidAmount)
            revert NotEnoughEth();

        // lock the challenge by making caller non-null
        challenges[challengeHash].caller = gear;
        // TODO what happens if at some point they change general.owner() function. Will my code break? check that any changes to the intenral logic of the General will not result in loss of bid etc. Once it's locked, then you can;t withdraw your ETH, not even by throwing errors in fire()

        emit ChallengeAccepted(
            challengeHash,
            address(gear.general),
            gear.fleetHash,
            msg.sender
        );
    }

    event ChallengeModified(
        bytes32 indexed challengeHash,
        uint256 indexed bidAmount,
        uint96 facilitatorPercentage,
        address preferredOpponent,
        address by
    );

    function modifyChallenge(
        Gear calldata oldGear,
        uint256 newBidAmount,
        uint96 newFacilitatorPercentage,
        IGeneral newPreferredOpponent
    ) external payable onlyOwnerOfGeneral(oldGear.general) {
        bytes32 challengeHash = _hashChallenge(oldGear);
        if (address(challenges[challengeHash].caller.general) != address(0))
            revert ChallengeAldreadyLocked();
        if (newFacilitatorPercentage > PERCENTAGE_SCALE)
            revert FaciliatorPercentageUnitsWrong();

        uint256 oldBidAmount = challenges[challengeHash].bidAmount;
        if (newBidAmount > oldBidAmount) {
            if (msg.value < (newBidAmount - oldBidAmount))
                revert NotEnoughEth();
        } else if (newBidAmount < oldBidAmount) {
            payable(msg.sender).transfer(oldBidAmount - newBidAmount);
        }
        challenges[challengeHash].bidAmount = newBidAmount;
        challenges[challengeHash]
            .facilitatorPercentage = newFacilitatorPercentage;
        challenges[challengeHash].preferredOpponent = newPreferredOpponent;

        emit ChallengeModified(
            challengeHash,
            newBidAmount,
            newFacilitatorPercentage,
            address(newPreferredOpponent),
            msg.sender
        );
    }

    event ChallengeWithdrawn(bytes32 indexed challengeHash, address by);

    function withdrawChallenge(Gear calldata gear)
        external
        onlyOwnerOfGeneral(gear.general)
    {
        bytes32 challengeHash = _hashChallenge(gear);
        if (address(challenges[challengeHash].caller.general) != address(0))
            revert ChallengeAldreadyLocked();
        uint256 bidAmount = challenges[challengeHash].bidAmount;
        if (bidAmount > 0) {
            payable(msg.sender).transfer(bidAmount);
            challenges[challengeHash].bidAmount = 0;
        }

        // challenge now becomes a "public good": anyone can play against it
        // but no ETH is involved
        delete challenges[challengeHash].preferredOpponent;

        emit ChallengeWithdrawn(challengeHash, msg.sender);
    }

    // fleet is represented using 64 bits. See Fleet library for the layout of bits
    using Fleet for uint64;
    // board is represented using 192 bits. See Board library for the layout of bits
    using Board for uint192;

    struct FleetAndBoard {
        uint64 fleet;
        uint192 board;
    }

    // fleetHash to FleetAndBoard
    mapping(uint96 => FleetAndBoard) public fleetsAndBoards;

    event FleetRevealed(
        uint96 indexed fleetHash,
        uint64 indexed fleet,
        bytes32 salt
    );

    function revealFleetsAndStartBattle(
        uint96 fleetHash1,
        uint64 fleet1,
        bytes32 salt1,
        uint96 fleetHash2,
        uint64 fleet2,
        bytes32 salt2,
        bytes32 challengeHash,
        uint256 maxTurns,
        address facilitatorFeeAddress
    ) external {
        revealFleet(fleetHash1, fleet1, salt1);
        revealFleet(fleetHash2, fleet2, salt2);
        startBattle(challengeHash, maxTurns, facilitatorFeeAddress);
    }

    function revealFleet(
        uint96 fleetHash,
        uint64 fleet,
        bytes32 salt
    ) public {
        // In order to obfuscate the fleet that a player starts with from the opponent,
        // we use fleetHash when commiting a/to Challenge. This phase allows you to "reveal your hand",
        // since the game is locked at this point, nothing can be changed about it.

        // in order to prevent memoization of fleet, an optional salt can be used to make it harder
        // to reverse the hashing operation. salt can be any data.

        if (
            fleetHash !=
            uint96(uint256(keccak256(abi.encodePacked(fleet, salt))))
        ) revert InvalidFleetHash();

        // this function not only makes sure that the revealed fleet actually corresponds to the
        // provided fleetHash earlier, but also makes sure that fleet obeys the rules of the game,
        // i.e. correct number of ships, correct placement, etc.
        uint192 board = fleet.validateFleetAndConvertToBoard();

        // also store the board representation of the fleet for faster lookup
        fleetsAndBoards[fleetHash] = FleetAndBoard(fleet, board);

        emit FleetRevealed(fleetHash, fleet, salt);
    }

    // attacks are represented using 192 bits. See Attacks library for the layout of bits
    using Attacks for uint192;

    uint256 internal constant WIN_REASON_TKO_INVALID_MOVE = 1;
    uint256 internal constant WIN_REASON_ELIMINATED_OPPONENT = 2;
    uint256 internal constant WIN_REASON_INFLICTED_MORE_DAMAGE = 3;
    uint256 internal constant DRAW = 5;
    uint256 internal constant NO_WINNER = 5;

    // To avoid stack too deep errors, use a struct to pack all vars into one var
    // https://medium.com/1milliondevs/compilererror-stack-too-deep-try-removing-local-variables-solved-a6bcecc16231
    struct GameState {
        // The first 3 arrays are constant
        // TODO is it possible to shave off gas due to them being constant?
        IGeneral[2] generals;
        uint64[2] fleets;
        uint192[2] boards;
        // everything else is not constant
        uint192[2] attacks;
        uint8[2] lastMoves;
        uint64[2] opponentsDiscoveredFleet;
        uint256[5][2] remainingCells;
        uint256 currentPlayerIdx;
        uint256 otherPlayerIdx;
        uint256 winnerIdx;
        uint256 winReason;
        uint8[] gameHistory;
    }

    event BattleConcluded(
        bytes32 indexed challengeHash,
        uint256 indexed winnerIdx,
        uint256 indexed winReason,
        uint8[] gameHistory,
        uint256 maxTurns,
        address facilitatorFeeAddress
    );

    function startBattle(
        bytes32 challengeHash,
        uint256 maxTurns,
        address facilitatorFeeAddress
    ) public {
        GameState memory gs = _getInitialGameState(challengeHash, maxTurns);

        if (address(gs.generals[1]) == address(0))
            revert ChallengeNeedsToBeLocked();
        if (gs.fleets[0] == 0 || gs.fleets[1] == 0)
            revert FleetsNeedToHaveBeenRevealed();
        if (
            ((maxTurns % 2) != 0) || (maxTurns < 21) // // the least amount of moves to win the game
        ) revert InvalidMaxTurns();

        for (uint256 i = 0; i < maxTurns; i++) {
            gs.otherPlayerIdx = (gs.currentPlayerIdx + 1) % 2;
            uint8 cellToFire;

            try
                gs.generals[gs.currentPlayerIdx].fire{gas: 4_000}(
                    gs.boards[gs.currentPlayerIdx],
                    gs.attacks[gs.currentPlayerIdx],
                    gs.attacks[gs.otherPlayerIdx],
                    gs.lastMoves[gs.currentPlayerIdx],
                    gs.lastMoves[gs.otherPlayerIdx],
                    gs.opponentsDiscoveredFleet[gs.currentPlayerIdx]
                )
            returns (uint8 ret) {
                cellToFire = ret;
            } catch {}

            gs.gameHistory[i + 1] = cellToFire;
            gs.lastMoves[gs.currentPlayerIdx] = cellToFire;

            if (cellToFire >= 64) {
                // if a general outputs a non-valid move, it's a TKO
                gs.winnerIdx = gs.otherPlayerIdx;
                gs.winReason = WIN_REASON_TKO_INVALID_MOVE;
                break;
            }

            // duplicate moves are ok
            if (
                !gs.attacks[gs.currentPlayerIdx].isOfType(
                    Attacks.EMPTY,
                    cellToFire
                )
            ) {
                gs.currentPlayerIdx = gs.otherPlayerIdx;
                continue;
            }

            uint8 hitShipType = gs.boards[gs.otherPlayerIdx].getShipAt(
                cellToFire
            );

            if (hitShipType == Fleet.EMPTY) {
                gs.attacks[gs.currentPlayerIdx] = gs
                    .attacks[gs.currentPlayerIdx]
                    .markAs(Attacks.MISS, cellToFire);
            } else {
                // it's a hit
                gs.attacks[gs.currentPlayerIdx] = gs
                    .attacks[gs.currentPlayerIdx]
                    .markAs(Attacks.HIT, cellToFire);

                // decrement number of cells remaining for the hit ship
                uint256 hitShipRemainingCells = --gs.remainingCells[
                    gs.otherPlayerIdx
                ][hitShipType - 1];

                if (hitShipRemainingCells == 0) {
                    // ship destroyed

                    if (gs.attacks[gs.currentPlayerIdx].hasWon()) {
                        gs.winnerIdx = gs.currentPlayerIdx;
                        gs.winReason = WIN_REASON_ELIMINATED_OPPONENT;
                        break;
                    }

                    gs.opponentsDiscoveredFleet[gs.currentPlayerIdx] = gs
                        .fleets[gs.otherPlayerIdx]
                        .copyShipTo(
                            gs.opponentsDiscoveredFleet[gs.currentPlayerIdx],
                            hitShipType
                        );
                }
            }

            gs.currentPlayerIdx = gs.otherPlayerIdx;
        }

        if (gs.winnerIdx == NO_WINNER) {
            // game terminated due to maxTotalTurns

            uint256 numberOfShipDestroyed0 = _getNumberOfDestroyedShips(
                gs.remainingCells,
                0
            );
            uint256 numberOfShipDestroyed1 = _getNumberOfDestroyedShips(
                gs.remainingCells,
                1
            );

            if (numberOfShipDestroyed0 > numberOfShipDestroyed1) {
                gs.winnerIdx = 0;
                gs.winReason = WIN_REASON_INFLICTED_MORE_DAMAGE;
            } else if (numberOfShipDestroyed0 < numberOfShipDestroyed1) {
                gs.winnerIdx = 1;
                gs.winReason = WIN_REASON_INFLICTED_MORE_DAMAGE;
            } // else draw
        }

        // Distribute the proceeds
        uint256 amountToSplit = challenges[challengeHash].bidAmount;

        if (amountToSplit > 0) {
            uint256 facilitatorFee = (amountToSplit *
                challenges[challengeHash].facilitatorPercentage) /
                PERCENTAGE_SCALE;
            payable(facilitatorFeeAddress).transfer(facilitatorFee);

            if (gs.winnerIdx == NO_WINNER) {
                amountToSplit = (amountToSplit - facilitatorFee) / 2;
                payable(gs.generals[0].owner()).transfer(amountToSplit);
                payable(gs.generals[1].owner()).transfer(amountToSplit);
            } else {
                amountToSplit -= facilitatorFee;
                payable(gs.generals[gs.winnerIdx].owner()).transfer(
                    amountToSplit
                );
            }
            challenges[challengeHash].bidAmount = 0;
        }

        // after game is played the challenge becomes a "public good". Anyone can accept the
        // challenge again and play for free
        delete challenges[challengeHash].caller;
        delete challenges[challengeHash].preferredOpponent;

        emit BattleConcluded(
            challengeHash,
            gs.winnerIdx,
            gs.winReason,
            gs.gameHistory,
            maxTurns,
            facilitatorFeeAddress
        );
    }

    function _getInitialGameState(bytes32 challengeHash, uint256 maxTurns)
        private
        view
        returns (GameState memory initialGameState)
    {
        initialGameState.generals = [
            challenges[challengeHash].challenger.general,
            challenges[challengeHash].caller.general
        ];

        {
            FleetAndBoard[2] memory fleetAndBoardsCached = [
                fleetsAndBoards[challenges[challengeHash].challenger.fleetHash],
                fleetsAndBoards[challenges[challengeHash].caller.fleetHash]
            ];
            initialGameState.fleets = [
                fleetAndBoardsCached[0].fleet,
                fleetAndBoardsCached[1].fleet
            ];
            initialGameState.boards = [
                fleetAndBoardsCached[0].board,
                fleetAndBoardsCached[1].board
            ];
        }

        initialGameState.attacks = [
            Attacks.EMPTY_ATTACKS,
            Attacks.EMPTY_ATTACKS
        ];
        initialGameState.lastMoves = [255, 255]; // initialize with 255 because 255 is an invalid move.
        //                                        valid moves are indicies into the 8x8 board, i.e. [0, 64)
        initialGameState.opponentsDiscoveredFleet = [
            Fleet.EMPTY_FLEET,
            Fleet.EMPTY_FLEET
        ];
        initialGameState.remainingCells = [
            [
                Fleet.PATROL_LENGTH,
                Fleet.DESTROYER_LENGTH,
                Fleet.DESTROYER_LENGTH,
                Fleet.CARRIER_LENGTH * Fleet.CARRIER_WIDTH,
                Fleet.BATTLESHIP_LENGTH
            ],
            [
                Fleet.PATROL_LENGTH,
                Fleet.DESTROYER_LENGTH,
                Fleet.DESTROYER_LENGTH,
                Fleet.CARRIER_LENGTH * Fleet.CARRIER_WIDTH,
                Fleet.BATTLESHIP_LENGTH
            ]
        ];

        // need to randomly choose first general to start firing
        // use the timestamp as random input
        initialGameState.currentPlayerIdx = uint256(block.timestamp) % 2;

        initialGameState.winnerIdx = NO_WINNER;
        initialGameState.winReason = DRAW;

        // used for emitting gameHistory in the event. first item in the history is the
        // idx of the first player to fire. The rest of the items are cells fired by players
        initialGameState.gameHistory = new uint8[](maxTurns + 1);
        initialGameState.gameHistory[0] = uint8(
            initialGameState.currentPlayerIdx
        );
    }

    function _getNumberOfDestroyedShips(
        uint256[5][2] memory remainingCells,
        uint256 playerIdx
    ) private pure returns (uint256 numberOfDestroyedShips) {
        for (uint256 i = 0; i < 5; i++) {
            if (remainingCells[playerIdx][i] == 0) {
                numberOfDestroyedShips++;
            }
        }
    }
}
