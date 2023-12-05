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

    function test_RevertWhenMaxSupplyReached() public {
        uint256 slot = stdstore
            .target(address(tbd))
            .sig(tbd.currentTokenId.selector)
            .find();

        bytes32 loc = bytes32(slot);
        bytes32 mockedCurrentTokenId = bytes32(abi.encode(tbd.MAX_SUPPLY));
        vm.store(address(tbd), loc, mockedCurrentTokenId);

        vm.expectRevert(MaxSupply.selector);
        tbd.mintAtPosition(0,0);
    }
}
