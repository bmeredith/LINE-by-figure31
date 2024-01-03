// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Constants} from "./Constants.sol";
import {MetadataGenerator} from "./MetadataGenerator.sol";
import {ITokenDescriptor} from "./ITokenDescriptor.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

error InvalidDirection();
error MintingClosed();
error MovementLocked();
error NotMinted();
error NotTokenOwner();
error PositionCurrentlyTaken(uint256 x, uint256 y);
error PositionNotMintable(uint256 x, uint256 y);
error PositionOutOfBounds(uint256 x, uint256 y);

contract TBD is ERC721, Ownable2Step, Constants {

    uint256 public currentTokenId = 1;
    bool private _canMove;
    bool private _isMintingClosed;

    MetadataGenerator private _metadataGenerator;

    uint256[NUM_COLUMNS][NUM_ROWS] public board;
    mapping(bytes32 => bool) public mintableCoordinates;
    mapping(uint256 => ITokenDescriptor.Token) public tokenIdToTokenInfo;

    constructor() ERC721("TBD", "TBD") Ownable(msg.sender) {
        _metadataGenerator = new MetadataGenerator();
    }

    function mintRandom() external payable {
        _mint(msg.sender, currentTokenId);
        currentTokenId++;
    }

    function mintAtPosition(uint256 x, uint256 y) external payable {
        uint256 tokenId = currentTokenId;    
        if (_isMintingClosed) {
            revert MintingClosed();
        }

        if (board[x][y] > 0) {
            revert PositionCurrentlyTaken(x, y);
        }

        bytes32 hash = _getCoordinateHash(ITokenDescriptor.Coordinate({x: x, y: y}));
        if (!mintableCoordinates[hash]) {
            revert PositionNotMintable(x, y);
        }

        board[x][y] = tokenId;
        tokenIdToTokenInfo[tokenId] = ITokenDescriptor.Token({
            initial: ITokenDescriptor.Coordinate({x: x, y: y}),
            current: ITokenDescriptor.Coordinate({x: x, y: y}),
            timestamp: block.timestamp,
            hasReachedEnd: false,
            direction: y < 13 ? ITokenDescriptor.Direction.DOWN : ITokenDescriptor.Direction.UP,
            numMovements: 0
        });

        if(tokenId != MAX_SUPPLY) {
            currentTokenId++;
        } else {
            _closeMint();
        }

        _mint(msg.sender, tokenId);
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
        if(!_canMove) {
            revert MovementLocked();
        }

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
        tokenIdToTokenInfo[currentTokenId].hasReachedEnd = ((token.direction == ITokenDescriptor.Direction.UP && y == 1) || (token.direction == ITokenDescriptor.Direction.DOWN && y == (NUM_ROWS - 1)));
        tokenIdToTokenInfo[currentTokenId].numMovements = token.numMovements++;
        tokenIdToTokenInfo[currentTokenId].timestamp = block.timestamp;
    }

    function setInitialAvailableCoordinates(ITokenDescriptor.Coordinate[] memory coordinates) external onlyOwner {
        for (uint256 i = 0; i < coordinates.length; i++) {
            bytes32 hash = _getCoordinateHash(coordinates[i]);
            mintableCoordinates[hash] = true;
        }
    }

    function closeMint() external onlyOwner {
        _closeMint();
    }

    function _closeMint() private {
        _isMintingClosed = true;
        _canMove = true;
    }

    function _getCoordinateHash(ITokenDescriptor.Coordinate memory coordinate) private pure returns (bytes32) {
        return keccak256(abi.encode(coordinate));
    }

    function getToken(uint256 tokenId) public view returns (ITokenDescriptor.Token memory) {
        return tokenIdToTokenInfo[tokenId];
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        if (ownerOf(id) == address(0))
            revert NotMinted();

        ITokenDescriptor.Token memory token = tokenIdToTokenInfo[id];
        return _metadataGenerator.generateMetadata(id, token);
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed.");
    }
}
