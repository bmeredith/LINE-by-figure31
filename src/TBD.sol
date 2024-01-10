// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Constants} from "./Constants.sol";
import {MetadataGenerator} from "./MetadataGenerator.sol";
import {ITokenDescriptor} from "./ITokenDescriptor.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

error IncorrectPrice();
error InvalidDirection();
error MintingClosed();
error MovementLocked();
error NotMinted();
error NotTokenOwner();
error PositionCurrentlyTaken(uint256 x, uint256 y);
error PositionNotMintable(uint256 x, uint256 y);
error PositionOutOfBounds(uint256 x, uint256 y);

contract TBD is ERC721, Ownable2Step, Constants {

    struct SalesConfig {
        uint64 startTime;
        uint64 endTime;
        uint256 startPriceInWei;
        uint256 endPriceInWei;
    }

    uint256 public currentTokenId = 1;
    bool private _canMove;
    bool private _isMintingClosed;

    MetadataGenerator private _metadataGenerator;
    SalesConfig public config;

    uint256[NUM_COLUMNS][NUM_ROWS] public board;
    mapping(bytes32 => bool) public mintableCoordinates;
    mapping(uint256 => ITokenDescriptor.Token) public tokenIdToTokenInfo;

    constructor() ERC721("TBD", "TBD") Ownable(msg.sender) {
        _metadataGenerator = new MetadataGenerator();
        config.startTime = uint64(1704369600);
        config.endTime = uint64(1704369600 + 3600);
        config.startPriceInWei = 1000000000000000000; // 1 eth
        config.endPriceInWei = 200000000000000000; // .2 eth
    }

    function mintRandom() external payable {
        _mint(msg.sender, currentTokenId);
        currentTokenId++;
    }

    function mintAtPosition(uint256 x, uint256 y) external payable {
        uint256 currentPrice = getCurrentPrice();
        uint256 tokenId = currentTokenId;    
        
        if (block.timestamp < config.startTime || _isMintingClosed) {
            revert MintingClosed();
        }

        if (board[x][y] > 0) {
            revert PositionCurrentlyTaken(x, y);
        }

        bytes32 hash = _getCoordinateHash(ITokenDescriptor.Coordinate({x: x, y: y}));
        if (!mintableCoordinates[hash]) {
            revert PositionNotMintable(x, y);
        }

        if (msg.value != currentPrice) {
            revert IncorrectPrice();
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

    function getCurrentPrice() public view returns (uint256) {
        uint256 elapsedTime = ((block.timestamp - config.startTime) / 10 ) * 10;        
        uint256 duration = config.endTime - config.startTime;
        uint256 halflife = 950; // adjust this to adjust speed of decay

        if (block.timestamp < config.startTime) {
            return config.startPriceInWei;
        }

        if (elapsedTime >= duration) {
            return config.endPriceInWei;
        }

        // h/t artblocks for exponential decaying price math
        uint256 decayedPrice = config.startPriceInWei;
        // Divide by two (via bit-shifting) for the number of entirely completed
        // half-lives that have elapsed since auction start time.
        decayedPrice >>= elapsedTime / halflife;
        // Perform a linear interpolation between partial half-life points, to
        // approximate the current place on a perfect exponential decay curve.
        decayedPrice -= (decayedPrice * (elapsedTime % halflife)) / halflife / 2;
        if (decayedPrice < config.endPriceInWei) {
            // Price may not decay below stay `basePrice`.
            return config.endPriceInWei;
        }
        
        return (decayedPrice / 1000000000000000) * 1000000000000000;
    }

    function moveNorth(uint256 tokenId) external {
        if(msg.sender != ownerOf(tokenId)) {
            revert NotTokenOwner();
        }

        if(tokenIdToTokenInfo[tokenId].direction != ITokenDescriptor.Direction.UP) {
            revert InvalidDirection();
        }

        _move(tokenId, 0, -1);
    }

    function moveNorthwest(uint256 tokenId) external {
        if(msg.sender != ownerOf(tokenId)) {
            revert NotTokenOwner();
        }

        if(tokenIdToTokenInfo[tokenId].direction != ITokenDescriptor.Direction.UP) {
            revert InvalidDirection();
        }

        _move(tokenId, -1, -1);
    }

    function moveNortheast(uint256 tokenId) external {
        if(msg.sender != ownerOf(tokenId)) {
            revert NotTokenOwner();
        }

        if(tokenIdToTokenInfo[tokenId].direction != ITokenDescriptor.Direction.UP) {
            revert InvalidDirection();
        }

        _move(tokenId, 1, -1);
    }

    function moveSouth(uint256 tokenId) external {
        if(msg.sender != ownerOf(tokenId)) {
            revert NotTokenOwner();
        }

        if(tokenIdToTokenInfo[tokenId].direction != ITokenDescriptor.Direction.DOWN) {
            revert InvalidDirection();
        }

        _move(tokenId, 0, 1);
    }

    function moveSouthwest(uint256 tokenId) external {
        if(msg.sender != ownerOf(tokenId)) {
            revert NotTokenOwner();
        }

        if(tokenIdToTokenInfo[tokenId].direction != ITokenDescriptor.Direction.DOWN) {
            revert InvalidDirection();
        }

        _move(tokenId, -1, 1);
    }

    function moveSoutheast(uint256 tokenId) external {
        if(msg.sender != ownerOf(tokenId)) {
            revert NotTokenOwner();
        }

        if(tokenIdToTokenInfo[tokenId].direction != ITokenDescriptor.Direction.DOWN) {
            revert InvalidDirection();
        }

        _move(tokenId, 1, 1);
    }

    function moveWest(uint256 tokenId) external {
        if(msg.sender != ownerOf(tokenId)) {
            revert NotTokenOwner();
        }

        _move(tokenId, -1, 0);
    }

    function moveEast(uint256 tokenId) external {
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
        if (ownerOf(id) == address(0)) {
            revert NotMinted();
        }

        ITokenDescriptor.Token memory token = tokenIdToTokenInfo[id];
        return _metadataGenerator.generateMetadata(id, token);
    }

    function updateConfig(
        uint64 startTime,
        uint64 endTime,
        uint256 startPriceInWei,
        uint256 endPriceInWei
    ) external onlyOwner {
        config.startTime = startTime;
        config.endTime = endTime;
        config.startPriceInWei = startPriceInWei;
        config.endPriceInWei = endPriceInWei;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed.");
    }
}
