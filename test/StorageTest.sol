// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

contract Storage {
    struct Gear {
        address general; // the general that contains the playing logic
        uint8 boardHash; // hash of the initial board which game starts with. hash is computed as keccak(hash + salt) where salt can by any data (just need to provide the same data in reveal board). The purpose of salt is to guard against board hash memoization that were already used
    }

    Gear private gear;

    function store(address general, uint8 boardHash) public {
        gear = Gear(general, boardHash);
    }

    function retrieve() public view returns (uint8) {
        return gear.boardHash;
    }
}

contract StorageTest is Test {
    Storage public storageContract;

    function setUp() public {
        storageContract = new Storage();
    }

    // function testStore(address general, uint8 boardHash) public {
    //     storageContract.store(general, boardHash);
    // }

    // function testRetrieve() public {
    //     storageContract.retrieve();
    // }

    // function _getBit() private return () {

    // }

    function testBit() public {
        uint8 a = 0x0;
        uint8 b = 0xFF;
        assertEq(a - 1, b);
    }
}
