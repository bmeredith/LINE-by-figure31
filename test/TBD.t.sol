// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {TBD} from "../src/TBD.sol";

contract TBDTest is Test {
    TBD private tbd;

    function setUp() public {
        tbd = new TBD();
    }
}
