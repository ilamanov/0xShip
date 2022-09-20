// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./generals/IGeneral.sol";
import "./utils/Fleet.sol";
import "./utils/Attacks.sol";
import "./utils/Board.sol";
import "./utils/BoardBuilder.sol";

/**
 * @title 0xShip: On-Chain Battleship Game
 * @author Nazar Ilamanov <@nazar_ilamanov>
 * @notice A composable and gas-efficient protocol for deploying splitter contracts.
 * @dev In the game, a challenger needs to submit a challenge by picking his gear (his general and initial board).
 * The challenger can also set bidAmount and/or preferredOpponent (of general type). Then only calls matching this criteria
 * will be able to matched. A caller then accepts the challenge that he likes by locking ETH (if there is a bidAmount).
 * That way the challenge will be locked. Players can then reveal their boards (from the hash), and the game can begin.
 * Game can begin by someone calling startBattle. Whoever calls will be provided 25% (or variable can be set) of the entire
 * bid to cover the gas fees of calling startBattle. Alternaitviely there is revealBoardsAndStartBattle that can combine
 * both steps
 */
contract Game {
    using Fleet for uint64;
    using Attacks for uint256;
    using Board for uint64;
    using BoardBuilder for BoardBuilder.BuildData;

    struct Challenge {
        Gear challenger; // initiator of the challenge. Can also set bidAmount and preferredOpponent
        Gear caller; // acceptor of the challenge. Need to provide bidAmount to lock the game
        uint256 bidAmount; // can be 0 if not playing for ETH, but then startBattle will need to be called manually as there is no incentive for MEV bots to call it for you
        // TODO struct pack the thing above. Maybe don't need 256 bits
        uint96 facilitatorPercentage; // the percent of the entire fee to go to whoever calls startBattle. set by challenger TODO explain units
        IGeneral preferredOpponent; // set by challenger. If non-zero, then only preferredOpponent can accept the challenge
    }

    // gear brought to the game
    struct Gear {
        IGeneral general; // the general that contains the playing logic
        uint96 boardHash; // hash of the initial board which game starts with. hash is computed as keccak(hash + salt) where salt can by any data (just need to provide the same data in reveal board). The purpose of salt is to guard against board hash memoization that were already used
    }

    // challengeHash to challenge. challengeHash = keccak(challengerGear)
    mapping(bytes32 => Challenge) private challenges;
    // boardHash to board. boardHash = keccak(board, salt). board is represented using 256 bits. See below
    mapping(uint96 => uint64) private boards;

    /** @notice Hashes a challenge
     *  @param challengerGear Gear used by the challenger. Challenger's gear is used as a way to "lock" the selected general and boardHash.
     *  @return computedHash Hash of the challenge.
     */
    function _hashChallenge(Gear memory challengerGear)
        private
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    challengerGear.general,
                    challengerGear.boardHash
                )
            );
    }

    modifier onlyOwnerOfGeneral(IGeneral general) {
        // TODO is there a reentrancy attack possible because calling general.owner?
        // TODO maybe inline this
        // check so players dont use other ppls code
        // Credit: 0xBeans
        require(general.owner() == msg.sender, "not your general");
        _;
    }

    // preferredOpponent can be null if don't care about who to play against
    function submitChallenge(
        Gear gear,
        uint96 facilitatorPercentage,
        IGeneral preferredOpponent
    ) external payable onlyOwnerOfGeneral(gear.general) {
        bytes32 challengeHash = _hashChallenge(gear);
        require(
            challenges[challengeHash].challenger.general == address(0),
            "challenge already exists"
        );
        // TODO is the following problematic? Is it better to do challenges[challengeHash] = Challenge(Gear(), null, msg.value, ...)
        challenges[challengeHash].challenger = gear;
        challenges[challengeHash].bidAmount = msg.value;
        challenges[challengeHash].facilitatorPercentage = facilitatorPercentage;
        challenges[challengeHash].preferredOpponent = preferredOpponent;
        // emit Event(); // TODO;
    }

    function modifyChallenge(
        Gear oldGear,
        uint256 newBidAmount,
        uint96 newFacilitatorPercentage,
        IGeneral newPreferredOpponent
    ) external payable onlyOwnerOfGeneral(oldGear.general) {
        bytes32 challengeHash = _hashChallenge(oldGear);
        require(
            challenges[challengeHash].caller.general == address(0), // TODO is that enough to check whether challenge has been locked? Do I also need to check boardHash? Also check other usages
            "challenge is already locked"
        );
        uint256 memory oldBidAmount = challenges[challengeHash].bidAmount;
        if (newBidAmount > oldBidAmount) {
            require(
                (newBidAmount - oldBidAmount) <= msg.value,
                "not enough ETH amount supplied"
            );
        } else if (newBidAmount < oldBidAmount) {
            // TODO transfer excess back to caller
        }
        challenges[challengeHash].bidAmount = newBidAmount;
        challenges[challengeHash]
            .facilitatorPercentage = newFacilitatorPercentage;
        challenges[challengeHash].preferredOpponent = newPreferredOpponent;
    }

    function withdrawChallenge(Gear gear)
        external
        onlyOwnerOfGeneral(gear.general)
    {
        bytes32 challengeHash = _hashChallenge(gear);
        require(
            challenges[challengeHash].caller.general == address(0),
            "challenge is already locked"
        );
        uint256 memory bidAmount = challenges[challengeHash].bidAmount;
        if (bidAmount > 0) {
            // refund back to user
        }
        challenges[challengeHash].bidAmount = 0;

        // TODO clear out the enitre challenge
    }

    function acceptChallenge(Gear gear, bytes32 challengeHash)
        external
        payable
        onlyOwnerOfGeneral(gear.general)
    {
        IGeneral memory preferredOpponent = challenges[challengeHash]
            .preferredOpponent;
        // after this make sure that none of the parameters about challenge (from both side) can be modified
        if (preferredOpponent != address(0)) {
            require(
                preferredOpponent == gear.general,
                "challenger does not want to play against you"
            );
        }
        require(
            challenges[challengeHash].bidAmount <= msg.value,
            "insufficient ETH amount supplied"
        );

        // lock the challenge by making caller non-null
        challenges[challengeHash].caller = gear;
        // TODO what happens if at some point they change general.owner() function. Will my code break?
    }

    function revealBoardsAndStartBattle(
        uint96 boardHash1,
        uint256 board1,
        bytes calldata salt1,
        uint96 boardHash2,
        uint256 board2,
        bytes calldata salt2,
        bytes32 challengeHash,
        uint256 maxTotalTurnsToPlay
    ) external {
        revealBoard(boardHash1, board1, salt1);
        revealBoard(boardHash2, board2, salt2);
        startBattle(challengeHash, maxTotalTurnsToPlay);
    }

    function revealBoard(
        uint96 boardHash,
        uint64 board,
        uint64 fleet, // LENGTHS- patrol: 2, destroyer: 3, destroyer: 3, carrier: (4, 2), battleship: 5
        bytes calldata salt
    ) public {
        // say in the comments explicitly that this does not require game to be locked
        // TODO validate board. Need to also make sure that correct number of each ship and that they are not too close to each other. and also bitwise sum of all bits is equal to total number of allowed cells
        require(
            boardHash ==
                uint96(uint256(keccak256(abi.encodePacked(board, salt)))),
            "invalid hash"
        );

        // make sure that fleet is correctly placed
        // no diagonal boards
        uint8 patrolStart = fleet.getPatrolCoordsStart();
        uint8 patrolEnd = fleet.getPatrolCoordsEnd();
        // Don't need to out of bounds check because fleet==board check will subsume it
        require(patrolEnd > patrolStart, "TODO");
        // require(patrolEnd < 64, "TODO"); no need because we mask it out in library
        require(
            (patrolEnd - patrolStart) == 1 || (patrolEnd - patrolStart) == 8,
            "TOOD"
        );

        uint8 firstDestroyerStart = fleet.getFirstDestroyerCoordsStart();
        uint8 firstDestroyerEnd = fleet.getFirstDestroyerCoordsEnd();
        require(firstDestroyerEnd > firstDestroyerStart, "TODO");
        require(
            (firstDestroyerEnd - firstDestroyerStart) == 2 ||
                (firstDestroyerEnd - firstDestroyerStart) == 16,
            "TOOD"
        );

        uint8 secondDestroyerStart = fleet.getSecondDestroyerCoordsStart();
        uint8 secondDestroyerEnd = fleet.getSecondDestroyerCoordsEnd();
        require(secondDestroyerEnd > secondDestroyerStart, "TODO");
        require(
            (secondDestroyerEnd - secondDestroyerStart) == 2 ||
                (secondDestroyerEnd - secondDestroyerStart) == 16,
            "TOOD"
        );

        uint8 carrierStart = fleet.getCarrierCoordsStart();
        uint8 carrierEnd = fleet.getCarrierCoordsEnd();
        require(carrierEnd > carrierStart, "TODO");
        require(
            (carrierEnd - carrierStart) == 11 ||
                (carrierEnd - carrierStart) == 25,
            "TOOD"
        );

        uint8 battleshipStart = fleet.getBattleshipCoordsStart();
        uint8 battleshipEnd = fleet.getBattleshipCoordsEnd();
        require(battleshipEnd > battleshipStart, "TODO");
        require(
            (battleshipEnd - battleshipStart) == 4 ||
                (battleshipEnd - battleshipStart) == 32,
            "TOOD"
        );

        // reconstruct the board from fleet info
        BoardBuilder.BuildData memory reconstructedBoard = BoardBuilder
            .BuildData(0, 0);
        reconstructedBoard = reconstructedBoard.placeShip(
            patrolStart,
            patrolEnd
        );
        reconstructedBoard = reconstructedBoard.placeShip(
            firstDestroyerStart,
            firstDestroyerEnd
        );
        reconstructedBoard = reconstructedBoard.placeShip(
            secondDestroyerStart,
            secondDestroyerEnd
        );
        reconstructedBoard = reconstructedBoard.placeShip(
            carrierStart,
            carrierEnd
        );
        reconstructedBoard = reconstructedBoard.placeShip(
            battleshipStart,
            battleshipEnd
        );

        // make sure that fleet corresponds to provided board
        require(
            reconstructedBoard.board == board,
            "fleet does not correpond to provided board"
        );

        boards[boardHash] = board;
    }

    // TODO custom errors. See 0xSplits

    function startBattle(bytes32 challengeHash, uint256 maxTotalTurnsToPlay)
        public
    {
        // TODO is it cheaper to cache challenges[challengeHash] first?
        // TODO these arrays need to be fixed size for efficiency
        // The first two arrays are also constant. Maybe can squeeze out some gas from this fact
        IGeneral[] memory generals = [
            challenges[challengeHash].challenger.general,
            challenges[challengeHash].caller.general
        ];
        require(generals[1] != address(0), "challenge needs to be locked");

        uint64[] memory initialBoards = [
            // this needs to be just the initial boards
            boards[challenges[challengeHash].challenger.boardHash],
            boards[challenges[challengeHash].caller.boardHash]
        ];
        require(
            initialBoards[0] != 0 && initialBoards[1] != 0,
            "boards need to have been revealed"
        );

        // TODO document layout of 128 bits in attacks
        uint256[] memory attacks = [
            Attacks.EMPTY_ATTACKS,
            Attacks.EMPTY_ATTACKS
        ];
        uint8[] memory lastMoves = [255, 255];
        uint64[] memory opponentsDiscoveredFleet = [
            Fleet.EMPTY_FLEET,
            Fleet.EMPTY_FLEET
        ];

        // TODO make sure that don't do duplicated checking of whether boards have been revealed if being called internally. maybe create an internal function that avoids this check
        // needs to give a payout to caller

        // validate turnsToPlay: needs to be even and >=threshold

        // need randomly choose first general to start fireing
        // Use the timestamp as random input.
        // TODO do I need to explicitly add "memory" to everything or is that default?
        uint8 currentPlayerIdx = uint8(block.timestamp) % 2; // TODO do  I need to take hash here. Also make sure that casting down takes rightmost bits
        uint8 otherPlayerIdx;

        int8 winnerIdx = -1;
        string memory winReason;

        for (; maxTotalTurnsToPlay > 0; maxTotalTurnsToPlay--) {
            otherPlayerIdx = (currentPlayerIdx + 1) % 2;
            // TODO also give context (prev moves last 3 moves, mine and opponents, which cells have already fired, hits, which fleet lost/destroyed, etc) on previous moves. They can probably store some kind of state in IGeneral contracts as well to track history and/or learn ML
            // TODO also limit this call on gas and get a default value if it errors out (try/catch) so that they don't lost. Maybe TKO for errors. technicheskoye porajeniye
            // probably don't provide pointer to Coordinator contract (and not only that but also explicitly guard against reentrancy because they can hardcode contract address)
            uint8 cellToFire = generals[currentPlayerIdx].fire(
                initialBoards[currentPlayerIdx],
                attacks[currentPlayerIdx],
                attacks[otherPlayerIdx],
                lastMoves[currentPlayerIdx],
                lastMoves[otherPlayerIdx],
                opponentsDiscoveredFleet[currentPlayerIdx]
            );

            lastMoves[currentPlayerIdx] = cellToFire;

            // validate move and apply state transition to board(s)
            // validate move: within board bounds,if not, need a default move - skip move
            // if make an error during move, you skip a turn (NO, TKO). continue. maybe combine with the above if statement
            if (cellToFire >= 64) {
                // TKO
                winnerIdx = otherPlayerIdx;
                winReason = "TKO due to invalid move";
                break;
            }
            // try. catch (TKO due to error in fire())

            // validate move: duplicates are ok
            if (!attacks[currentPlayerIdx].isUntouched(cellToFire)) {
                // a duplicate attack. skip the rest of the logic
                currentPlayerIdx = otherPlayerIdx;
                continue;
            }

            attacks[currentPlayerIdx] = attacks[currentPlayerIdx].markAsMiss(
                cellToFire
            );

            if (initialBoards[otherPlayerIdx].isHit(cellToFire)) {
                // TODO change to getFleet() == 0
                attacks[currentPlayerIdx].markAsHit(cellToFire);

                if (
                    initialBoards[otherPlayerIdx].isDestroyed(
                        attacks[currentPlayerIdx],
                        cellToFire
                    )
                ) {
                    //TODO combine is Destroyed with fleet detection and combine with memoization of cells left
                    attacks[currentPlayerIdx].markAsDestroyed(cellToFire);
                    // TODO mark as destroyed not just this cell but all cells. Need to combine with memoization
                    // maybe don't nneed to mark adjacent and mark discovered fleet when game is won. But maybe need it for logging the history in the event
                    attacks[currentPlayerIdx].markAdjacentToDestroyed(
                        cellToFire
                    );

                    // TODO mark discoveredOpponentsFleet

                    if (attacks[currentPlayerIdx].isWon()) {
                        // TODO win
                        winnerIdx = currentPlayerIdx;
                        winReason = "eliminated opponent";
                        break;
                    }
                }

                // maybe also send a boolean lastTurnSunkedOtherShip.
            }

            currentPlayerIdx = otherPlayerIdx;
        }

        if (winnerIdx == -1) {
            // game terminated due to maxTotalTurns
            // needs to be static length
            uint8[] memory numberOfShipDestroyed = [
                opponentsDiscoveredFleet[0].numberOfShipsDestroyed(),
                opponentsDiscoveredFleet[1].numberOfShipsDestroyed()
            ]; // This needs to be memoized for easier calc
            if (numberOfShipDestroyed[0] > numberOfShipDestroyed[1]) {
                winnerIdx = 0;
                winReason = "more damage nanesen";
            } else if (numberOfShipDestroyed[0] < numberOfShipDestroyed[1]) {
                winnerIdx = 1;
                winReason = "more damage nanesen";
            } // else draw
        }

        if (winnerIdx == -1) {
            // draw. distribute funds equally.
        } else {
            // distriubte funds to the winner
        }

        // distribute fudns to the caller

        // what happens after game is played? does it become public good? No. So clear out the challenge.
    }

    // TODO add function to withdrawDonationsETH, withdrawDonationsERC20 - probably need an "donationsAddress", "owner", etc
}

// TODO event for ownership transferred. maybe not. What is the purpose of events? Which ones are needed for the game. Does game care about ownership transfer? Check each function if it requires an event
// TODO should do public functions internal per Mudit? https://mudit.blog/solidity-tips-and-tricks-to-save-gas-and-reduce-bytecode-size/#2a76
// TODO use memory/calldata for arguments whenever possible
// where to use calldata, where to declare variables with memory explicitly
// TODO license for the game
