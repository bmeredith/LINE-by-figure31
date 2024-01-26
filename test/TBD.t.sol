// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/TBD.sol";

contract TBDTest is Test {
    using stdStorage for StdStorage;

    TBD private tbd;
    bytes32[] emptyMerkleProof;

    function setUp() public {
        tbd = new TBD(address(0));
        vm.warp(1704369600);
    }

    function test_mint_revertWhenMaxSupplyReached() public {
        mockCurrentTokenId(tbd.MAX_SUPPLY());
        tbd.setInitialAvailableCoordinates(_generateCoordinates(2));

        tbd.mintAtPosition{value: 1000000000000000000}(generateSingleCoordinateArray(0, 0), emptyMerkleProof);

        vm.expectRevert(MintingClosed.selector);
        tbd.mintAtPosition{value: 1000000000000000000}(generateSingleCoordinateArray(0, 1), emptyMerkleProof);
    }

    function test_mint_revertWhenMintIsClosed() public {
        tbd.setInitialAvailableCoordinates(_generateCoordinates(1));

        tbd.closeMint();

        vm.expectRevert(MintingClosed.selector);
        tbd.mintAtPosition{value: 1000000000000000000}(generateSingleCoordinateArray(0, 0), emptyMerkleProof);
    }

    function test_mint_revertWhenPositionIsTaken() public {
        bytes32 firstBoardSlot = getBoardPositionSlot(0, 0);
        bytes32 mockedFirstBoardSlotValue = bytes32(abi.encode(1));
        vm.store(address(tbd), firstBoardSlot, mockedFirstBoardSlotValue);

        vm.expectRevert(abi.encodeWithSelector(PositionCurrentlyTaken.selector, 0, 0));
        tbd.mintAtPosition{value: 1000000000000000000}(generateSingleCoordinateArray(0, 0), emptyMerkleProof);
    }

    function test_mint_revertWhenPositionIsNotMintable() public {
        tbd.setInitialAvailableCoordinates(_generateCoordinates(1));

        vm.expectRevert(abi.encodeWithSelector(PositionNotMintable.selector, 5, 5));
        tbd.mintAtPosition{value: 1000000000000000000}(generateSingleCoordinateArray(5, 5), emptyMerkleProof);
    }

    function test_mint_mintedCoordinateIsTokenIdOnBoard() public {
        tbd.setInitialAvailableCoordinates(_generateCoordinates(1));

        tbd.mintAtPosition{value: 1000000000000000000}(generateSingleCoordinateArray(0, 0), emptyMerkleProof);

        uint256 value = getBoardPositionValue(0, 0);
        assertEq(1, value);
    }

    function test_mint() public {
        console.log(tbd.getCurrentPrice());
        tbd.setInitialAvailableCoordinates(_generateCoordinates(1));

        tbd.mintAtPosition{value: 1000000000000000000}(generateSingleCoordinateArray(0, 0), emptyMerkleProof);
        string memory tokenUri = tbd.tokenURI(1);
        console.log(tokenUri);
    }

    function test_mint_mintedTokenHasCorrectDirection() public {
        ITokenDescriptor.Coordinate[] memory coordinates = new ITokenDescriptor.Coordinate[](2);
        coordinates[0] = ITokenDescriptor.Coordinate({x: 0, y: 12});
        coordinates[1] = ITokenDescriptor.Coordinate({x: 0, y: 13});
        tbd.setInitialAvailableCoordinates(coordinates);

        tbd.mintAtPosition{value: 1000000000000000000}(generateSingleCoordinateArray(0, 12), emptyMerkleProof);
        tbd.mintAtPosition{value: 1000000000000000000}(generateSingleCoordinateArray(0, 13), emptyMerkleProof);

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

    function _generateCoordinates(uint256 count) private pure returns (ITokenDescriptor.Coordinate[] memory) {
        ITokenDescriptor.Coordinate[] memory coordinates = new ITokenDescriptor.Coordinate[](count);
        for(uint256 i=0;i < count;i++) {
            coordinates[i] = (ITokenDescriptor.Coordinate({x: 0, y: i}));
        }

        return coordinates;
    }

    function generateSingleCoordinateArray(uint256 x, uint256 y) private pure returns (ITokenDescriptor.Coordinate[] memory) {
        ITokenDescriptor.Coordinate[] memory coordinates = new ITokenDescriptor.Coordinate[](1);
        coordinates[0] = ITokenDescriptor.Coordinate({x: x, y: y});
        return coordinates;
    }
}
