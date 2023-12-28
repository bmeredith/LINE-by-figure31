// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ITokenDescriptor} from "./ITokenDescriptor.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

// implement DA from Web contract
// add max qty
// start time
// end time?
// is there a AL?

// be able to close out mint prior to 200 pieces being minted

error InvalidDirection();
error MaxSupply();
error NotMinted();
error NotTokenOwner();
error PositionCurrentlyTaken(uint256 x, uint256 y);
error PositionNotMintable(uint256 x, uint256 y);
error PositionOutOfBounds(uint256 x, uint256 y);

contract TBD is ERC721, Ownable2Step {

    uint256 public constant NUM_ROWS = 25;
    uint256 public constant NUM_COLUMNS = 25;

    uint256[NUM_COLUMNS][NUM_ROWS] public board;
    uint256 public currentTokenId = 1;
    mapping(bytes32 => bool) public mintableCoordinates;
    mapping(uint256 => ITokenDescriptor.Token) public tokenIdToTokenInfo;

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

        bytes32 hash = getCoordinateHash(ITokenDescriptor.Coordinate({x: x, y: y}));
        if (!mintableCoordinates[hash]) {
            revert PositionNotMintable(x, y);
        }

        board[x][y] = currentTokenId;
        tokenIdToTokenInfo[currentTokenId] = ITokenDescriptor.Token({
            initial: ITokenDescriptor.Coordinate({x: x, y: y}),
            current: ITokenDescriptor.Coordinate({x: x, y: y}),
            timestamp: block.timestamp,
            hasReachedEnd: false,
            direction: y < 13 ? ITokenDescriptor.Direction.DOWN : ITokenDescriptor.Direction.UP,
            numMovements: 0
        });

        _mint(msg.sender, currentTokenId);
        currentTokenId++;
    }

    function moveUp(uint256 tokenId) external {
        if(msg.sender != ownerOf(tokenId)) {
            revert NotTokenOwner();
        }

        if(tokenIdToTokenInfo[tokenId].direction != ITokenDescriptor.Direction.UP) {
            revert InvalidDirection();
        }

        _move(tokenId, 0, -1);
    }

    function moveDown(uint256 tokenId) external {
        if(msg.sender != ownerOf(tokenId)) {
            revert NotTokenOwner();
        }

        if(tokenIdToTokenInfo[tokenId].direction != ITokenDescriptor.Direction.DOWN) {
            revert InvalidDirection();
        }

        _move(tokenId, 0, 1);
    }

    function moveLeft(uint256 tokenId) external {
        if(msg.sender != ownerOf(tokenId)) {
            revert NotTokenOwner();
        }

        _move(tokenId, -1, 0);
    }

    function moveRight(uint256 tokenId) external {
        if(msg.sender != ownerOf(tokenId)) {
            revert NotTokenOwner();
        }

        _move(tokenId, 1, 0);
    }

    function _move(uint256 tokenId, int256 xDelta, int256 yDelta) private {
        ITokenDescriptor.Token memory token = tokenIdToTokenInfo[tokenId];
        uint256 x = 0;
        if (xDelta == -1) {
            x = token.current.x - 1;
        } else if (xDelta == 1) {
            x = token.current.x + 1;
        }

        uint256 y = 0;
        if (yDelta == -1) {
            y = token.current.y + 1;
        } else if(yDelta == 1) {
            y = token.current.y - 1;
        }

        if(x < 1 || x >= NUM_COLUMNS || y < 1 || y >= NUM_ROWS) {
            revert PositionOutOfBounds(x,y);
        }

        if(board[x][y] > 0) {
            revert PositionCurrentlyTaken(x,y);
        }

        board[token.current.x][token.current.y] = 0;
        board[x][y] = tokenId;

        tokenIdToTokenInfo[currentTokenId].current = ITokenDescriptor.Coordinate({x: x, y: y});
        tokenIdToTokenInfo[currentTokenId].hasReachedEnd = (y == 1 || y == (NUM_ROWS - 1));
        tokenIdToTokenInfo[currentTokenId].numMovements = token.numMovements++;
        tokenIdToTokenInfo[currentTokenId].timestamp = block.timestamp;
    }

    function setInitialAvailableCoordinates(ITokenDescriptor.Coordinate[] memory coordinates) external onlyOwner {
        for (uint256 i = 0; i < coordinates.length; i++) {
            bytes32 hash = getCoordinateHash(coordinates[i]);
            mintableCoordinates[hash] = true;
        }
    }

    function getCoordinateHash(ITokenDescriptor.Coordinate memory coordinate) private pure returns (bytes32) {
        return keccak256(abi.encode(coordinate));
    }

    function getToken(uint256 tokenId) public view returns (ITokenDescriptor.Token memory) {
        return tokenIdToTokenInfo[tokenId];
    }

    // image filename = (y * NUM_ROWS) + x
    // number of days passed = (token.timestamp / 1 days) % 3600
    // cycle point = number of days passed % 10
    // if (cycle point % 2 == 0) origin photo
    // else if cycle point ==
    //   1 == left
    //   3 == upper left
    //   5 == up
    //   7 == upper right
    //   9 == right
    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        if (ownerOf(id) == address(0))
            revert NotMinted();
    }
}
