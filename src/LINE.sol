// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Constants} from "./Constants.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Descriptor} from "./Descriptor.sol";
import {ITokenDescriptor} from "./ITokenDescriptor.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

error ExceedsMaxMintPerTransaction();
error HasNotReachedEnd();
error IncorrectPrice();
error InvalidDirection();
error MaxLockedOriginPointsAlreadyReached();
error MintingClosed();
error MovementLocked();
error NotMinted();
error NotTokenOwner();
error OriginPointLocked();
error PositionCurrentlyTaken(uint256 x, uint256 y);
error PositionNotMintable(uint256 x, uint256 y);
error PositionOutOfBounds(uint256 x, uint256 y);

contract LINE is ERC721, Ownable2Step, ReentrancyGuard, Constants {

    using SafeTransferLib for address payable;

    struct SalesConfig {
        uint64 startTime;
        uint64 endTime;
        uint256 startPriceInWei;
        uint256 endPriceInWei;
    }
    
    uint256 public constant MAX_LOCKED_TOKENS = 20;
    uint256 public constant MAX_MINT_PER_TX = 3;
    uint256 public constant MAX_SUPPLY = 200;

    bytes32 public merkleRoot;
    uint256 public currentTokenId = 1;
    uint256 public numLockedOriginPoints;
    bool private _canMove;
    bool private _isMintingClosed;

    ITokenDescriptor public descriptor;
    SalesConfig public config;

    ITokenDescriptor.Coordinate[] public availableCoordinates;
    uint256[NUM_COLUMNS][NUM_ROWS] public grid;
    mapping(bytes32 => bool) public mintableCoordinates;
    mapping(uint256 => ITokenDescriptor.Token) public tokenIdToTokenInfo;
    mapping(bytes32 => uint256) public coordinateHashToIndex;

    constructor(address _descriptor) ERC721("LINE", "LINE") Ownable(msg.sender) {
        descriptor = ITokenDescriptor(_descriptor);
        config.startTime = uint64(1704369600);
        config.endTime = uint64(1704369600 + 3600);
        config.startPriceInWei = 1000000000000000000; // 1 eth
        config.endPriceInWei = 200000000000000000; // .2 eth
    }

    function mintRandom(uint256 quantity, bytes32[] calldata merkleProof) external payable nonReentrant {
        if (quantity > MAX_MINT_PER_TX) {
            revert ExceedsMaxMintPerTransaction();
        }
        
        uint256 currentPrice = getCurrentPrice();
        if (merkleProof.length > 0) {
            bool hasDiscount = checkMerkleProof(merkleProof, msg.sender, merkleRoot);
            if (hasDiscount) {
                currentPrice = (currentPrice * 80) / 100; // 20% off
            }
        }

        if (msg.value < (currentPrice * quantity)) {
            revert IncorrectPrice();
        }

        for (uint256 i=0; i < quantity;) {
            ITokenDescriptor.Coordinate memory coordinateToMint = availableCoordinates[0];
            _mintWithChecks(coordinateToMint);

            unchecked {
                ++i;
            }
        }
    }

    function mintAtPosition(ITokenDescriptor.Coordinate[] memory coordinates, bytes32[] calldata merkleProof) external payable nonReentrant {
        uint256 numCoordinates = coordinates.length;
        if (numCoordinates > MAX_MINT_PER_TX) {
            revert ExceedsMaxMintPerTransaction();
        }
        
        uint256 currentPrice = getCurrentPrice();
        if (merkleProof.length > 0) {
            bool hasDiscount = checkMerkleProof(merkleProof, msg.sender, merkleRoot);
            if (hasDiscount) {
                currentPrice = (currentPrice * 80) / 100; // 20% off
            }
        }

        if (msg.value < (currentPrice * numCoordinates)) {
            revert IncorrectPrice();
        }

        for (uint256 i=0; i < numCoordinates;) {
            _mintWithChecks(coordinates[i]);

            unchecked {
                ++i;
            }
        }
    }

    function _mintWithChecks(ITokenDescriptor.Coordinate memory coordinate) internal {
        if (block.timestamp < config.startTime || _isMintingClosed) {
            revert MintingClosed();
        }
        
        uint256 tokenId = currentTokenId;
        uint256 x = coordinate.x;
        uint256 y = coordinate.y;

        if (grid[x][y] > 0) {
            revert PositionCurrentlyTaken(x, y);
        }

        bytes32 hash = _getCoordinateHash(ITokenDescriptor.Coordinate({x: x, y: y}));
        if (!mintableCoordinates[hash]) {
            revert PositionNotMintable(x, y);
        }

        grid[x][y] = tokenId;
        tokenIdToTokenInfo[tokenId] = ITokenDescriptor.Token({
            initial: ITokenDescriptor.Coordinate({x: x, y: y}),
            current: ITokenDescriptor.Coordinate({x: x, y: y}),
            timestamp: block.timestamp,
            hasReachedEnd: false,
            isLocked: false,
            direction: y < 13 ? ITokenDescriptor.Direction.DOWN : ITokenDescriptor.Direction.UP,
            numMovements: 0
        });

        if (tokenId != MAX_SUPPLY) {
            currentTokenId++;
        } else {
            _closeMint();
        }
        
        _removeFromAvailability(coordinateHashToIndex[hash]);
        _mint(msg.sender, tokenId);
    }

    function getCurrentPrice() public view returns (uint256) {      
        uint256 duration = config.endTime - config.startTime;
        uint256 halflife = 950; // adjust this to adjust speed of decay

        if (block.timestamp < config.startTime) {
            return config.startPriceInWei;
        }

        uint256 elapsedTime = ((block.timestamp - config.startTime) / 10 ) * 10;  
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

    function getGrid() external view returns (uint256[NUM_COLUMNS][NUM_ROWS] memory) {
        return grid;
    }

    function moveNorth(uint256 tokenId) external {
        if (tokenIdToTokenInfo[tokenId].direction != ITokenDescriptor.Direction.UP) {
            revert InvalidDirection();
        }

        _move(tokenId, 0, -1);
    }

    function moveNorthwest(uint256 tokenId) external {
        if (tokenIdToTokenInfo[tokenId].direction != ITokenDescriptor.Direction.UP) {
            revert InvalidDirection();
        }

        _move(tokenId, -1, -1);
    }

    function moveNortheast(uint256 tokenId) external {
        if (tokenIdToTokenInfo[tokenId].direction != ITokenDescriptor.Direction.UP) {
            revert InvalidDirection();
        }

        _move(tokenId, 1, -1);
    }

    function moveSouth(uint256 tokenId) external {
        if (tokenIdToTokenInfo[tokenId].direction != ITokenDescriptor.Direction.DOWN) {
            revert InvalidDirection();
        }

        _move(tokenId, 0, 1);
    }

    function moveSouthwest(uint256 tokenId) external {
        if (tokenIdToTokenInfo[tokenId].direction != ITokenDescriptor.Direction.DOWN) {
            revert InvalidDirection();
        }

        _move(tokenId, -1, 1);
    }

    function moveSoutheast(uint256 tokenId) external {
        if (tokenIdToTokenInfo[tokenId].direction != ITokenDescriptor.Direction.DOWN) {
            revert InvalidDirection();
        }

        _move(tokenId, 1, 1);
    }

    function moveWest(uint256 tokenId) external {
        _move(tokenId, -1, 0);
    }

    function moveEast(uint256 tokenId) external {
        _move(tokenId, 1, 0);
    }

    function _move(uint256 tokenId, int256 xDelta, int256 yDelta) private {
        if (msg.sender != ownerOf(tokenId)) {
            revert NotTokenOwner();
        }

        if (!_canMove) {
            revert MovementLocked();
        }

        ITokenDescriptor.Token memory token = tokenIdToTokenInfo[tokenId];
        if (token.isLocked) {
            revert OriginPointLocked();
        }

        uint256 x = 0;
        if (xDelta == -1) {
            x = token.current.x - 1;
        } else if (xDelta == 1) {
            x = token.current.x + 1;
        }

        uint256 y = 0;
        if (yDelta == -1) {
            y = token.current.y + 1;
        } else if (yDelta == 1) {
            y = token.current.y - 1;
        }

        if (_isPositionOutOfBounds(x, y)) {
            revert PositionOutOfBounds(x,y);
        }

        if (grid[x][y] > 0) {
            revert PositionCurrentlyTaken(x,y);
        }

        grid[token.current.x][token.current.y] = 0;
        grid[x][y] = tokenId;

        tokenIdToTokenInfo[currentTokenId].current = ITokenDescriptor.Coordinate({x: x, y: y});
        tokenIdToTokenInfo[currentTokenId].hasReachedEnd = ((token.direction == ITokenDescriptor.Direction.UP && y == 1) || (token.direction == ITokenDescriptor.Direction.DOWN && y == (NUM_ROWS - 1)));
        tokenIdToTokenInfo[currentTokenId].numMovements = token.numMovements++;
        tokenIdToTokenInfo[currentTokenId].timestamp = block.timestamp;
    }

    function lockOriginPoint(uint256 tokenId, uint256 x, uint256 y) external {
        if (msg.sender != ownerOf(tokenId)) {
            revert NotTokenOwner();
        }

        if (_isPositionOutOfBounds(x, y)) {
            revert PositionOutOfBounds(x,y);
        }

        if (grid[x][y] > 0) {
            revert PositionCurrentlyTaken(x,y);
        }

        if (numLockedOriginPoints == MAX_LOCKED_TOKENS) {
            revert MaxLockedOriginPointsAlreadyReached();
        }

        ITokenDescriptor.Token memory token = tokenIdToTokenInfo[tokenId];
        if (!token.hasReachedEnd) {
            revert HasNotReachedEnd();
        }

        tokenIdToTokenInfo[currentTokenId].current = ITokenDescriptor.Coordinate({x: x, y: y});
        tokenIdToTokenInfo[currentTokenId].timestamp = block.timestamp;
        tokenIdToTokenInfo[tokenId].isLocked = true;
        numLockedOriginPoints++;
    }

    function getAvailableCoordinates() external view returns (ITokenDescriptor.Coordinate[] memory) {
        return availableCoordinates;
    }

    function setInitialAvailableCoordinates(ITokenDescriptor.Coordinate[] calldata coordinates) external onlyOwner {
        for (uint256 i = 0; i < coordinates.length; i++) {
            bytes32 hash = _getCoordinateHash(coordinates[i]);
            mintableCoordinates[hash] = true;
            coordinateHashToIndex[hash] = i;
            availableCoordinates.push(coordinates[i]);
        }
    }

    function closeMint() external onlyOwner {
        _closeMint();
    }
    
    function checkMerkleProof(
        bytes32[] calldata merkleProof,
        address _address,
        bytes32 _root
    ) public pure returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(_address));
        return MerkleProof.verify(merkleProof, _root, leaf);
    }

    function getToken(uint256 tokenId) public view returns (ITokenDescriptor.Token memory) {
        return tokenIdToTokenInfo[tokenId];
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        if (ownerOf(id) == address(0)) {
            revert NotMinted();
        }

        ITokenDescriptor.Token memory token = tokenIdToTokenInfo[id];
        return descriptor.generateMetadata(id, token);
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

    function setDescriptor(address _descriptor) external onlyOwner {
        descriptor = ITokenDescriptor(_descriptor);
    }

    function updateMerkleRoot(bytes32 _root) external onlyOwner {
        merkleRoot = _root;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed.");
    }

    function _closeMint() private {
        _isMintingClosed = true;
        _canMove = true;
    }

    function _getCoordinateHash(ITokenDescriptor.Coordinate memory coordinate) private pure returns (bytes32) {
        return keccak256(abi.encode(coordinate));
    }

    function _isPositionOutOfBounds(uint256 x, uint256 y) private pure returns (bool) {
        return x < 1 || x >= NUM_COLUMNS || y < 1 || y >= NUM_ROWS;
    }

    function _removeFromAvailability(uint256 index) private {
        uint256 lastCoordinateIndex = availableCoordinates.length - 1;
        ITokenDescriptor.Coordinate memory lastCoordinate = availableCoordinates[lastCoordinateIndex];
        ITokenDescriptor.Coordinate memory coordinateToBeRemoved = availableCoordinates[index];

        availableCoordinates[index] = lastCoordinate;
        coordinateHashToIndex[_getCoordinateHash(lastCoordinate)] = index;
        delete coordinateHashToIndex[_getCoordinateHash(coordinateToBeRemoved)];
        availableCoordinates.pop();
    }
}
