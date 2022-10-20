// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/utils/Attacks.sol";

contract AttacksTest is Test {
    using Attacks for uint256;

    function setUp() public {}

    function testHammingDistance64(uint256 x) public {
        x &= 0xFFFFFFFFFFFFFFFF;
        assertEq(x.hammingDistance64(), hammingDistance64Correct(x));
    }

    function hammingDistance64Correct(uint256 x)
        private
        pure
        returns (uint256 countOfOnes)
    {
        for (uint256 i = 0; i < 64; i++) {
            countOfOnes += ((x >> i) & 1);
        }
    }
}
