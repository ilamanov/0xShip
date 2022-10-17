// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

error NotYourGeneral();
error ChallengeDoesNotExist();
error ChallengeAldreadyExists();
error ChallengeAldreadyLocked();
error ChallengeNeedsToBeLocked();
error ChallengerDoesNotWantToPlayAgainstYou();
error FleetsNeedToHaveBeenRevealed();
error FaciliatorPercentageUnitsWrong();
error NotEnoughEth();
error InvalidFleetHash();
error InvalidMaxTurns();

interface IGame {
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
        uint256 indexed winnerIdx,
        uint256 indexed winReason,
        uint256[] gameHistory,
        uint256 maxTurns,
        address facilitatorFeeAddress
    );
}
