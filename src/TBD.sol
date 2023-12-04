// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC721A } from "ERC721A/ERC721A.sol";

// implement DA from Web contract
// add max qty
// start time
// end time?
// is there a AL?

// be able to close out mint prior to 200 pieces being minted

error PositionCurentlyTaken(uint256 x, uint256 y);
error PositionNotMintable(uint256 x, uint256 y);

contract TBD is ERC721A {

    enum Direction {
        UP,
        DOWN
    }

    struct Coordinate {
        uint256 x;
        uint256 y;
    }
    
    struct Token {
        // have a field that is where the origin point is pointing to for that day
        Coordinate initial;
        Coordinate current;
        uint256 timestamp;
        bool hasReachedEnd;
        Direction direction;
        uint256 numMovements;
    }

    mapping(bytes32 => bool) public _mintableCoordinates;
    mapping(uint256 => Token) public tokenIdToTokenInfo;

    constructor() ERC721A("Tbd", "TBD") { } 

    // check uninitialized value of arrays pls
    uint256[25][25] board = [
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    ];

    // over an hour
    // 1eth to 0.2 resting price??
    function mintAtRandom() external payable {
        // check supply
        // check if price matches current price from auction
        // keep track of available positions in an array?
        // on last mint, enable moving to be allowed
        _mint(msg.sender, 1);
    }

    // make multiple?
    function mintAtPosition(uint256 x, uint256 y) external payable {
        // check supply
        // check if price matches current price from auction
        // check if position is a mintable position*
        // check if position is taken*
        // check if y is less than 10 -> set direction to DOWN, else UP*
        if(board[x][y] > 0) {
            revert PositionCurentlyTaken(x, y); 
        }

        bytes32 hash = getCoordinateHash(Coordinate({x: x, y: y}));
        if(!_mintableCoordinates[hash]) {
            revert PositionNotMintable(x, y);
        }

        uint256 tokenId = _nextTokenId();
        board[x][y] = tokenId;
        tokenIdToTokenInfo[tokenId] = Token({
            initial: Coordinate({x: x, y: y}),
            current: Coordinate({x: x, y: y}),
            timestamp: block.timestamp,
            hasReachedEnd: false,
            direction: y < 13 ? Direction.DOWN : Direction.UP,
            numMovements: 0
        });

        _mint(msg.sender, 1);
    }

    // move up, left, right, down functions instead?
    function move(uint256 tokenId, int256 x, int256 y) external {
        // check if owner of tokenid
        // check if x > 1
        // check if y > 1
        // check if x is out of bound
        // check if y is out of bound
        // check if result x,y is already taken
    }

    function setInitialAvailableCoordinates(Coordinate[] memory coordinates) external {
        for(uint256 i=0;i < coordinates.length;i++) {
            bytes32 hash = getCoordinateHash(coordinates[i]);
            _mintableCoordinates[hash] = true;
        }
    }

    function getCoordinateHash(Coordinate memory coordinate) pure private returns(bytes32) {
        return keccak256(abi.encode(coordinate));
    }

    function _startTokenId() override internal view virtual returns (uint256) {
        return 1;
    }
}