// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import "./IGeneral.sol";

// contract SmartGeneral is IGeneral {
//     using Attacks for uint256; // TODO need to add helper methods for getting status of cell: whether it's 0, 1, 2, 3. Only one quarter can be 1 at a time.
//     // TODO helper to convert to consecutive (seg...) layout where one cell is represented by 2 bits and then next cell comes. Maybe a parameter of which type of layout General wants.

//     address private _owner;

//     constructor() {
//         _owner = msg.sender;
//     }

//     function owner() external view virtual returns (address) {
//         return _owner;
//     }

//     function fire(
//         uint64 myInitialBoard, // 8x8 board - initial placement
//         uint256 myAttacks, // 8x8 board: 2 bits: 0 not touched, 1 miss, 2 hit, 3 destroyed
//         uint256 opponentsAttacks,
//         uint8 myLastMove,
//         uint8 opponentsLastMove,
//         uint64 opponentsDiscoveredFleet // remaining types and coords and types of destroyed to easier guess layout of opponent's initial board (use quadrants for uniform guess or based on hunch - opponent likes to vtykat in smaller area), remaining fleet type needs to be indexable by type to quickly check whether avianosets has been destroyed already
//     )
//         external
//         virtual
//         returns (
//             // opponent based strategies: if opponent is known for spreading boards uniformly, then hunch is uniform
//             // TODO remaining fleet type for efficient calculation of shortest length
//             // TODO discovered enemy's fleet: coords and types for also easier inference of horizontal vs vertical layout
//             // TO add prev move (mine and opponent's) and metadata (remaining fleet amount can be guessed from attack's destroyed quadrant =(x-myAttacks.numberOfDestroyedCells()))
//             uint8
//         )
//     {
//         // maybe some bots will decide to remember guessed direction and store to avoid duplicate gas wasting and use remaining gas for more advanced strategies
//         // 6 bytes to index 8x8=64
//         /*
//             if (not hits pending (can already be destroyed)) { TODO how to efficiently check if no 2s in myAttacks. pack all 2s in one chunk .[000000001 (1indicates) that this slot is zero 00 - 64 times][64 times for 1s][64 times for 2s][64 times for 3s]
//                 we need to guess
//                 we do random or strategic guess depending on stage of the game
//                 at the end of the game, we do strategic guessing based on quadrants and shortest remaining ship
//                 at the beginning and mid stage we do guesses based on quadrants and hunch (prev experience)
//             }
//             if (there is a hit) {
//                 need to track
//             }
//             only 2 modes

//         */
//         // TODO after fire, Game will have to update all 4 quarters in myAttacks, becuase cell is spread out over 4 quarters
//         if (myAttacks.hasAPendingHit()) {
//             // implemented under the hood using whther 3rd quadrant != 0
//             // TODO track
//         } else {
//             uint6 numberOfNonTouchedCells = myAttacks.numberOfNonTouchedCells();
//             // can also use metadata about remaining fleet to guess stage of game.
//             if (numberOfNonTouchedCells > 50) {
//                 // beginning of the game
//                 // find quadrant with least amount of action (miss + destroyed) and pick a cell there randomly to shoot
//                 // hunch: tries to minimize surface area so puts closer to edges
//             } else if (numberOfNonTouchedCells > 35) {
//                 // will not be uniformly spread because at the end of the game numberOfNonTouchedCells != 0
//                 // mid game
//                 // scan for big chunks of empty fields where ship could fit and fire there
//                 // like maybe there is a big rectangle or long line
//             } else {
//                 // end game
//             }
//         }
//         return cellToFire;
//     }
// }

// // TODO step by step replay to see where could improve
// // TODO provide all data so that even ML can learn.
// // in the UI need to show historic performance (also historic way of picking initial boards)
// // people can also add plugins - create another contract that allows people to play against bots by reusing the same bots
// // TODO another strategy that scans all previous layouts and tries to match so far discovered layout to older one
