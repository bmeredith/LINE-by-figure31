// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/TBD.sol";

contract TBDTest is Test {
    using stdStorage for StdStorage;

    TBD private tbd;

    function setUp() public {
        tbd = new TBD();
    }
}
