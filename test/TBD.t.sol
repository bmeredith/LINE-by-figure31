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

    function test_mintAtPosition_revertWhenMaxSupplyReached() public {
        uint256 slot = stdstore
            .target(address(tbd))
            .sig(tbd.currentTokenId.selector)
            .find();

        bytes32 mockedCurrentTokenId = bytes32(abi.encode(tbd.MAX_SUPPLY));
        vm.store(address(tbd), bytes32(slot), mockedCurrentTokenId);

        vm.expectRevert(MaxSupply.selector);
        tbd.mintAtPosition(0,0);
    }

    function test_mintAtPosition_revertWhenPositionIsTaken() public {
        uint256 firstBoardSlot = stdstore
            .target(address(tbd))
            .sig("board(uint256,uint256)")
            .with_key(uint256(0))
            .with_key(uint256(0))
            .find();

        bytes32 mockedFirstBoardSlot = bytes32(abi.encode(1));
        vm.store(address(tbd), bytes32(firstBoardSlot), mockedFirstBoardSlot);

        vm.expectRevert(abi.encodeWithSelector(PositionCurrentlyTaken.selector, 0, 0));
        tbd.mintAtPosition(0,0);
    }
}
