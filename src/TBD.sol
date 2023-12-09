// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

// implement DA from Web contract
// add max qty
// start time
// end time?
// is there a AL?

// be able to close out mint prior to 200 pieces being minted

error MaxSupply();
error NotTokenOwner();
error PositionCurrentlyTaken(uint256 x, uint256 y);
error PositionNotMintable(uint256 x, uint256 y);

contract TBD is ERC721, Ownable2Step {
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

    uint256[25][25] public board;
    uint256 public currentTokenId = 1;
    mapping(bytes32 => bool) public mintableCoordinates;
    mapping(uint256 => Token) public tokenIdToTokenInfo;

    uint256 public constant MAX_SUPPLY = 200;

    constructor() ERC721("TBD", "TBD") Ownable(msg.sender) {}

    // over an hour
    // 1eth to 0.2 resting price??
    function mintAtRandom() external payable {
        // check supply
        // check if price matches current price from auction
        // keep track of available positions in an array?
        // on last mint, enable moving to be allowed

        _mint(msg.sender, currentTokenId);
        currentTokenId++;
    }

    // make multiple?
    function mintAtPosition(uint256 x, uint256 y) external payable {
        // check supply*
        // check if mint is locked
        // check if price matches current price from auction
        // check if position is a mintable position*
        // check if position is taken*
        // check if y is less than 10 -> set direction to DOWN, else UP*

        if (currentTokenId + 1 > MAX_SUPPLY) {
            revert MaxSupply();
        }

        if (board[x][y] > 0) {
            revert PositionCurrentlyTaken(x, y);
        }

        bytes32 hash = getCoordinateHash(Coordinate({x: x, y: y}));
        if (!mintableCoordinates[hash]) {
            revert PositionNotMintable(x, y);
        }

        board[x][y] = currentTokenId;
        tokenIdToTokenInfo[currentTokenId] = Token({
            initial: Coordinate({x: x, y: y}),
            current: Coordinate({x: x, y: y}),
            timestamp: block.timestamp,
            hasReachedEnd: false,
            direction: y < 13 ? Direction.DOWN : Direction.UP,
            numMovements: 0
        });

        _mint(msg.sender, currentTokenId);
        currentTokenId++;
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
        for (uint256 i = 0; i < coordinates.length; i++) {
            bytes32 hash = getCoordinateHash(coordinates[i]);
            mintableCoordinates[hash] = true;
        }
    }

    function getCoordinateHash(Coordinate memory coordinate) private pure returns (bytes32) {
        return keccak256(abi.encode(coordinate));
    }

    function getToken(uint256 tokenId) public view returns (Token memory) {
        return tokenIdToTokenInfo[tokenId];
    }

    // number of days passed = (token.timestamp / 1 days) % 3600
    // cycle point = number of days passed % 10
    // if (cycle point % 2 == 0) origin photo
    // else if cycle point ==
    //   1 == left
    //   3 == upper left
    //   5 == up
    //   7 == upper right
    //   9 == right
    function tokenURI(uint256 id) public view virtual override returns (string memory) {}
}
