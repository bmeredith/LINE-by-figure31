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

    function test_mint_revertWhenMaxSupplyReached() public {
        mockCurrentTokenId(tbd.MAX_SUPPLY());

        vm.expectRevert(MaxSupply.selector);
        tbd.mintAtPosition(0,0);
    }

    function test_mint_revertWhenPositionIsTaken() public {
        bytes32 firstBoardSlot = getBoardPositionSlot(0, 0);
        bytes32 mockedFirstBoardSlotValue = bytes32(abi.encode(1));
        vm.store(address(tbd), firstBoardSlot, mockedFirstBoardSlotValue);

        vm.expectRevert(abi.encodeWithSelector(PositionCurrentlyTaken.selector, 0, 0));
        tbd.mintAtPosition(0,0);
    }

    function test_mint_revertWhenPositionIsNotMintable() public {
        mockMintableCoordinate(0, 0, false);

        vm.expectRevert(abi.encodeWithSelector(PositionNotMintable.selector, 0, 0));
        tbd.mintAtPosition(0,0);
    }

    function test_mint_mintedCoordinateIsTokenIdOnBoard() public {
        mockMintableCoordinate(0, 0, true);

        tbd.mintAtPosition(0,0);

        uint256 value = getBoardPositionValue(0, 0);
        assertEq(1, value);
    }

    function test_mint_mintedTokenHasCorrectDirection() public {
        mockMintableCoordinate(0, 12, true);
        mockMintableCoordinate(0, 13, true);

        tbd.mintAtPosition(0,12);
        tbd.mintAtPosition(0,13);

        assertTrue(tbd.getToken(1).direction == ITokenDescriptor.Direction.DOWN);
        assertTrue(tbd.getToken(2).direction == ITokenDescriptor.Direction.UP);
    }

    function mockCurrentTokenId(uint256 tokenId) private {
        bytes32 currentTokenIdSlot = getCurrentTokenIdSlot();
        bytes32 mockedCurrentTokenId = bytes32(tokenId);
        vm.store(address(tbd), currentTokenIdSlot, mockedCurrentTokenId);
    }

    function mockMintableCoordinate(uint256 x, uint256 y, bool isMintable) private {
        bytes32 hash = keccak256(abi.encode(ITokenDescriptor.Coordinate({x: x, y: y})));
        bytes32 mintableCoordinateSlot = getIsMintableCoordinateSlot(hash);
        bytes32 mockedIsMintableSlotValue = bytes32(abi.encode(isMintable));
        vm.store(address(tbd), mintableCoordinateSlot, mockedIsMintableSlotValue);
    }

    function getIsMintableCoordinateSlot(bytes32 hash) private returns (bytes32) {
        uint256 isMintableSlot = stdstore
            .target(address(tbd))
            .sig("mintableCoordinates(bytes32)")
            .with_key(hash)
            .find();

        return bytes32(isMintableSlot);
    }

    function getCurrentTokenIdSlot() private returns (bytes32) {
        uint256 slot = stdstore
            .target(address(tbd))
            .sig(tbd.currentTokenId.selector)
            .find();

        return bytes32(slot);
    }

    function getBoardPositionSlot(uint256 x, uint256 y) private returns (bytes32) {
        uint256 boardSlot = stdstore
            .target(address(tbd))
            .sig("board(uint256,uint256)")
            .with_key(x)
            .with_key(y)
            .find();

        return bytes32(boardSlot);
    }

    function getBoardPositionValue(uint256 x, uint256 y) private returns (uint256) {
        return stdstore
            .target(address(tbd))
            .sig("board(uint256,uint256)")
            .with_key(x)
            .with_key(y)
            .read_uint();
    }
}
