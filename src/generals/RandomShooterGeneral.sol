// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import "./IGeneral.sol";

// contract RandomShooterGeneral is IGeneral {
//     address private _owner;

//     constructor() {
//         _owner = msg.sender;
//     }

//     function owner() external view virtual returns (address) {
//         return _owner;
//     }

//     function fire(
//         uint64 myBoard, // 8x8 board - initial placement
//         uint256 myAttacks, // 8x8 board: 4 bits: 0 not touched, 1 miss, 2 hit, 3 destroyed
//         uint256 otherAttacks
//     )
//         external
//         virtual
//         returns (
//             // TO add prev move and metadata
//             uint6
//         )
//     {
//         // 6 bytes to index 8x8=64
//         // TODO maybe return a smaller size int?
//         // this will be used as initial entropy
//         uint32 cellsCovered = bitwiseSum(myAttack); // TODO maybe smaller size?
//         // this may overshoot because adjacent cells are marked as attacked automatically when ship sinks, but still
//         uint72 cellToFire = uint72(
//             uint256(keccak256(abi.encode(cellsCovered)))
//         );
//         while (myAttacks[cellToFire] != 0) {
//             cellToFire = uint72(
//                 uint256(keccak256(abi.encode(cellToFire + cellsCovered)))
//             );
//         }
//         return cellToFire;
//     }
// }
