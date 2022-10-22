// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./generals/IGeneral.sol";
import "./utils/Attacks.sol";
import "./utils/Fleet.sol";
import "./utils/Board.sol";

error ChallengeDoesNotExist();
error ChallengeAldreadyExists();
error ChallengeAldreadyLocked();
error ChallengeNeedsToBeLocked();
error ChallengerDoesNotWantToPlayAgainstYou();
error FaciliatorPercentageUnitsWrong();
error FleetsNeedToHaveBeenRevealed();
error NotYourGeneral();
error NotEnoughEth();
error InvalidChallengeIndex();
error InvalidFleetHash();
error InvalidMaxTurns();

/**
 * @title 0xShip: On-Chain Battleship Game
 * @author Nazar Ilamanov <@nazar_ilamanov>
 * @notice Here is how the game works at a high level:
 * 1. A challenger submits a Challenge py picking a general (the contract
 *    that has playing logic) and the fleet.
 * 2. Anyone can then then accept this challenge. (To accept the challenge
 *    you need to provide your own general and fleet). Accepting the
 *    challenge locks a battle between the challenger and the caller.
 * 3. At this point, nothing can be modified about the game. Next step is
 *    to reveal your fleet and start the battle. Both of these operations
 *    can be performed by a 3rd party facilitator that will be compensated
 *    by a percentage of game bid.

 * (Fleet reveal is necessary because fleet is initially obfuscated by
 * providing only the hash of the fleet. This is so that opponents don't
 * know each other's fleet before the battle begins).
 */
contract Game {
    // -------------------------------------------- EVENTS --------------------------------------------

    event ChallengeSubmitted(
        bytes32 indexed challengeHash,
        uint256 indexed bidAmount,
        address indexed general,
        uint96 fleetHash,
        uint96 facilitatorPercentage,
        address preferredOpponent
    );
    event ChallengeAccepted(
        bytes32 indexed challengeHash,
        address indexed general,
        uint96 fleetHash
    );
    event ChallengeModified(
        bytes32 indexed challengeHash,
        uint256 indexed bidAmount,
        uint96 facilitatorPercentage,
        address preferredOpponent
    );
    event ChallengeWithdrawn(bytes32 indexed challengeHash);
    event FleetRevealed(
        uint96 indexed fleetHash,
        uint256 indexed fleet,
        bytes32 salt
    );
    event BattleConcluded(
        bytes32 indexed challengeHash,
        address indexed challengerGeneral,
        address indexed callerGeneral,
        uint256 challengerBoard,
        uint256 callerBoard,
        uint256 bidAmount,
        uint256 facilitatorPercentage,
        uint256 winnerIdx,
        uint256 outcome,
        uint256[] gameHistory,
        uint256 maxTurns
    );

    // ---------------- LOGIC FOR SUBMITTING/ACCEPTING/MODIFYING/WITHDRAWING CHALLENGES ----------------

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
    mapping(bytes32 => Challenge) public challenges;
    // all challengeHashes
    bytes32[] public challengeHashes;

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

    function _hashChallenge(Gear memory challengerGear)
        private
        pure
        returns (bytes32)
    {
        // challenger's gear is hashed as a way to "lock" the selected general and fleetHash.
        // but, the internal logic of the general can still be modified
        return
            keccak256(
                abi.encodePacked(
                    challengerGear.general,
                    challengerGear.fleetHash
                )
            );
    }

    modifier onlyOwnerOfGeneral(IGeneral general) {
        // check so players dont use other ppls code. Credit: 0xBeans
        if (general.owner() != msg.sender) revert NotYourGeneral();
        _;
    }

    function isChallengerGeneralSet(bytes32 challengeHash)
        private
        view
        returns (bool)
    {
        return
            address(challenges[challengeHash].challenger.general) != address(0);
    }

    function isCallerGeneralSet(bytes32 challengeHash)
        private
        view
        returns (bool)
    {
        return address(challenges[challengeHash].caller.general) != address(0);
    }

    // constant to scale uints into percentages (1e4 == 100%)
    uint96 private constant PERCENTAGE_SCALE = 1e4;

    function submitChallenge(
        Gear calldata gear,
        uint96 facilitatorPercentage,
        IGeneral preferredOpponent
    ) external payable onlyOwnerOfGeneral(gear.general) {
        bytes32 challengeHash = _hashChallenge(gear);
        if (isChallengerGeneralSet(challengeHash))
            revert ChallengeAldreadyExists();
        if (facilitatorPercentage > PERCENTAGE_SCALE)
            revert FaciliatorPercentageUnitsWrong();

        challenges[challengeHash].challenger = gear;
        challenges[challengeHash].bidAmount = msg.value;
        challenges[challengeHash].facilitatorPercentage = facilitatorPercentage;
        challenges[challengeHash].preferredOpponent = preferredOpponent;
        challengeHashes.push(challengeHash);

        emit ChallengeSubmitted(
            challengeHash,
            msg.value,
            address(gear.general),
            gear.fleetHash,
            facilitatorPercentage,
            address(preferredOpponent)
        );
    }

    function acceptChallenge(Gear calldata gear, bytes32 challengeHash)
        external
        payable
        onlyOwnerOfGeneral(gear.general)
    {
        if (!isChallengerGeneralSet(challengeHash))
            revert ChallengeDoesNotExist();
        if (isCallerGeneralSet(challengeHash)) revert ChallengeAldreadyLocked();

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

        emit ChallengeAccepted(
            challengeHash,
            address(gear.general),
            gear.fleetHash
        );
    }

    function modifyChallenge(
        Gear calldata oldGear,
        uint256 newBidAmount,
        uint96 newFacilitatorPercentage,
        IGeneral newPreferredOpponent
    ) external payable onlyOwnerOfGeneral(oldGear.general) {
        bytes32 challengeHash = _hashChallenge(oldGear);
        if (!isChallengerGeneralSet(challengeHash))
            revert ChallengeDoesNotExist();
        if (isCallerGeneralSet(challengeHash)) revert ChallengeAldreadyLocked();
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
            address(newPreferredOpponent)
        );
    }

    function withdrawChallenge(Gear calldata gear, uint256 challengeIdx)
        external
        onlyOwnerOfGeneral(gear.general)
    {
        bytes32 challengeHash = _hashChallenge(gear);
        if (isCallerGeneralSet(challengeHash)) revert ChallengeAldreadyLocked();

        uint256 bidAmount = challenges[challengeHash].bidAmount;
        if (bidAmount > 0) {
            payable(msg.sender).transfer(bidAmount);
        }

        if (challengeHashes[challengeIdx] != challengeHash)
            revert InvalidChallengeIndex();

        delete challenges[challengeHash];
        challengeHashes[challengeIdx] = challengeHashes[
            challengeHashes.length - 1
        ];
        challengeHashes.pop();

        emit ChallengeWithdrawn(challengeHash);
    }

    // -------------------------------------- LOGIC FOR REVEALING FLEET --------------------------------------

    // fleet uses 64 bits. See Fleet library for the layout of bits
    using Fleet for uint256;
    // board uses 192 bits. See Board library for the layout of bits
    using Board for uint256;

    struct FleetAndBoard {
        // in storage we only store what's necessary in order to bit-pack
        uint64 fleet;
        uint192 board;
    }

    // fleetHash to FleetAndBoard
    mapping(uint96 => FleetAndBoard) public fleetsAndBoards;

    function revealFleetsAndStartBattle(
        uint96 fleetHash1,
        uint256 fleet1,
        bytes32 salt1,
        uint96 fleetHash2,
        uint256 fleet2,
        bytes32 salt2,
        bytes32 challengeHash,
        uint256 challengeIdx,
        uint256 maxTurns,
        address facilitatorFeeAddress
    ) external {
        revealFleet(fleetHash1, fleet1, salt1);
        revealFleet(fleetHash2, fleet2, salt2);
        startBattle(
            challengeHash,
            challengeIdx,
            maxTurns,
            facilitatorFeeAddress
        );
    }

    function revealFleet(
        uint96 fleetHash,
        uint256 fleet,
        bytes32 salt
    ) public {
        // In order to obfuscate the fleet that a player starts with from the opponent,
        // we use fleetHash when commiting a/to Challenge.
        // After the challenge is accepted, the game is locked. Nothing can be changed about it.
        // So, now it's safe to reveal the fleet

        // in order to prevent memoization of fleet (rainbow attack), an optional salt can be
        // used to make it harder to reverse the hashing operation. salt can be any data.

        if (
            fleetHash !=
            uint96(uint256(keccak256(abi.encodePacked(fleet, salt))))
        ) revert InvalidFleetHash();

        // this function not only makes sure that the revealed fleet actually corresponds to the
        // provided fleetHash earlier, but also makes sure that fleet obeys the rules of the game,
        // i.e. correct number of ships, correct placement, etc.
        uint256 board = fleet.validateFleetAndConvertToBoard();

        // also store the board representation of the fleet for faster lookup
        fleetsAndBoards[fleetHash] = FleetAndBoard(
            uint64(fleet),
            uint192(board)
        );

        emit FleetRevealed(fleetHash, fleet, salt);
    }

    // ------------------------------------ LOGIC FOR PLAYING THE GAME ------------------------------------

    // attacks are represented using 192 bits. See Attacks library for the layout of bits
    using Attacks for uint256;

    uint256 internal constant OUTCOME_DRAW = 5;
    uint256 internal constant OUTCOME_ELIMINATED_OPPONENT = 1;
    uint256 internal constant OUTCOME_INFLICTED_MORE_DAMAGE = 2;
    uint256 internal constant NO_WINNER = 5;

    // To avoid stack too deep errors, use a struct to pack all game vars into one var
    // https://medium.com/1milliondevs/compilererror-stack-too-deep-try-removing-local-variables-solved-a6bcecc16231
    struct GameState {
        // The first 3 arrays are constant
        // TODO is it possible to shave off gas due to them being constant?
        IGeneral[2] generals;
        uint256[2] fleets;
        uint256[2] boards;
        // everything else is not constant
        uint256[2] attacks;
        uint256[2] lastMoves;
        uint256[2] opponentsDiscoveredFleet;
        uint256[5][2] remainingCells;
        uint256 currentPlayerIdx;
        uint256 otherPlayerIdx;
        uint256 winnerIdx;
        uint256 outcome;
        uint256[] gameHistory;
    }

    function startBattle(
        bytes32 challengeHash,
        uint256 challengeIdx,
        uint256 maxTurns,
        address facilitatorFeeAddress
    ) public {
        GameState memory gs = _getInitialGameState(challengeHash, maxTurns);

        if (address(gs.generals[1]) == address(0))
            revert ChallengeNeedsToBeLocked();
        if (gs.fleets[0] == 0 || gs.fleets[1] == 0)
            revert FleetsNeedToHaveBeenRevealed();
        if (
            ((maxTurns % 2) != 0) || (maxTurns < 21) // 21 is the least amount of moves to win the game
        ) revert InvalidMaxTurns();

        uint256 i;
        for (; i < maxTurns; i++) {
            gs.otherPlayerIdx = (gs.currentPlayerIdx + 1) % 2;

            uint256 returnedVal;
            uint256 cellToFire;
            try
                gs.generals[gs.currentPlayerIdx].fire{gas: 5_000}(
                    gs.boards[gs.currentPlayerIdx],
                    gs.attacks[gs.currentPlayerIdx],
                    gs.attacks[gs.otherPlayerIdx],
                    gs.lastMoves[gs.currentPlayerIdx],
                    gs.lastMoves[gs.otherPlayerIdx],
                    gs.opponentsDiscoveredFleet[gs.currentPlayerIdx]
                )
            returns (uint256 ret) {
                returnedVal = ret;
                cellToFire = ret & 63; // take last 6 bits only. 63 is 111111 in binary
            } catch {}

            gs.gameHistory[i + 1] = cellToFire;
            gs.lastMoves[gs.currentPlayerIdx] = returnedVal;

            // duplicate moves are ok
            if (
                !gs.attacks[gs.currentPlayerIdx].isOfType(
                    cellToFire,
                    Attacks.UNTOUCHED
                )
            ) {
                gs.currentPlayerIdx = gs.otherPlayerIdx;
                continue;
            }

            uint256 hitShipType = gs.boards[gs.otherPlayerIdx].getShipAt(
                cellToFire
            );

            if (hitShipType == Fleet.EMPTY) {
                gs.attacks[gs.currentPlayerIdx] = gs
                    .attacks[gs.currentPlayerIdx]
                    .markAs(cellToFire, Attacks.MISS);
                gs.currentPlayerIdx = gs.otherPlayerIdx;
                continue;
            }

            // it's a hit
            gs.attacks[gs.currentPlayerIdx] = gs
                .attacks[gs.currentPlayerIdx]
                .markAs(cellToFire, Attacks.HIT);

            // decrement number of cells remaining for the hit ship
            uint256 hitShipRemainingCells = --gs.remainingCells[
                gs.otherPlayerIdx
            ][hitShipType - 1];

            if (hitShipRemainingCells == 0) {
                // ship destroyed

                if (gs.attacks[gs.currentPlayerIdx].hasWon()) {
                    gs.winnerIdx = gs.currentPlayerIdx;
                    gs.outcome = OUTCOME_ELIMINATED_OPPONENT;
                    gs.gameHistory[i + 2] = 255;
                    break;
                }

                gs.opponentsDiscoveredFleet[gs.currentPlayerIdx] = gs
                    .fleets[gs.otherPlayerIdx]
                    .copyShipTo(
                        gs.opponentsDiscoveredFleet[gs.currentPlayerIdx],
                        uint8(hitShipType)
                    );
            }

            gs.currentPlayerIdx = gs.otherPlayerIdx;
        }

        if (gs.winnerIdx == NO_WINNER) {
            // game terminated due to maxTotalTurns
            gs.gameHistory[i + 1] = 255;

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
                gs.outcome = OUTCOME_INFLICTED_MORE_DAMAGE;
            } else if (numberOfShipDestroyed0 < numberOfShipDestroyed1) {
                gs.winnerIdx = 1;
                gs.outcome = OUTCOME_INFLICTED_MORE_DAMAGE;
            } // else draw
        }

        // Distribute the proceeds
        {
            uint256 bidAmount = challenges[challengeHash].bidAmount;
            uint256 amountToSplit = 2 * bidAmount;
            uint256 facilitatorPercentage = challenges[challengeHash]
                .facilitatorPercentage;

            if (amountToSplit > 0) {
                uint256 facilitatorFee = (amountToSplit *
                    facilitatorPercentage) / PERCENTAGE_SCALE;
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
            }

            emit BattleConcluded(
                challengeHash,
                address(gs.generals[0]),
                address(gs.generals[1]),
                gs.boards[0],
                gs.boards[1],
                bidAmount,
                facilitatorPercentage,
                gs.winnerIdx,
                gs.outcome,
                gs.gameHistory,
                maxTurns
            );
        }

        if (challengeHashes[challengeIdx] != challengeHash)
            revert InvalidChallengeIndex();

        delete challenges[challengeHash];
        challengeHashes[challengeIdx] = challengeHashes[
            challengeHashes.length - 1
        ];
        challengeHashes.pop();
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
                uint256(fleetAndBoardsCached[0].fleet),
                uint256(fleetAndBoardsCached[1].fleet)
            ];
            initialGameState.boards = [
                uint256(fleetAndBoardsCached[0].board),
                uint256(fleetAndBoardsCached[1].board)
            ];
        }

        initialGameState.attacks = [
            Attacks.EMPTY_ATTACKS,
            Attacks.EMPTY_ATTACKS
        ];
        initialGameState.lastMoves = [uint256(255), uint256(255)]; // initialize with 255 which indicates start of the game.
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

        // need to randomly choose first general to start firing.
        // use the timestamp as random input
        initialGameState.currentPlayerIdx = uint256(block.timestamp) % 2;

        initialGameState.winnerIdx = NO_WINNER;
        initialGameState.outcome = OUTCOME_DRAW;

        // used for emitting gameHistory in the event. first item in the history is the
        // idx of the first player to fire. Last item is 255 which indicates end of game.
        // the rest of the items are cells fired by players
        initialGameState.gameHistory = new uint256[](maxTurns + 2);
        initialGameState.gameHistory[0] = initialGameState.currentPlayerIdx;
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
