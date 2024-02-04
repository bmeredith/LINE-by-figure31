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
        address payable fundsRecipient;
    }
    
    uint256 public constant MAX_LOCKED_TOKENS = 20;
    uint256 public constant MAX_MINT_PER_TX = 3;
    uint256 public constant MAX_SUPPLY = 200;
    uint256 internal immutable FUNDS_SEND_GAS_LIMIT = 210_000;

    bytes32 public holdersMerkleRoot;
    bytes32 public fpMembersMerkleRoot;

    uint256 public currentTokenId = 1;
    uint256 public numLockedOriginPoints;
    bool public canMove;
    uint256 private  _totalSupply;
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
        config.fundsRecipient = payable(msg.sender);
    }

    function mintRandom(uint256 quantity, bytes32[] calldata merkleProof) external payable nonReentrant {
        if (quantity > MAX_MINT_PER_TX) {
            revert ExceedsMaxMintPerTransaction();
        }
        
        uint256 currentPrice = getCurrentPrice();
        if (merkleProof.length > 0) {
            currentPrice = _getDiscountedCurrentPrice(merkleProof, msg.sender, currentPrice);
        }

        uint256 totalPrice = currentPrice * quantity;
        if (msg.value < totalPrice) {
            revert IncorrectPrice();
        }

        uint256 ethToReturn;
        for (uint256 i=0; i < quantity;) {
            ITokenDescriptor.Coordinate memory coordinateToMint = availableCoordinates[0];
            bool success = _mintWithChecks(coordinateToMint);
            if (!success) {
                ethToReturn += currentPrice;
            }

            unchecked {
                ++i;
            }
        }

        // return eth for any pieces that failed to mint because a point on the board was already taken when the mint occurred
        if (ethToReturn > 0) {
            payable(msg.sender).safeTransferETH(ethToReturn);
        }
    }

    function mintAtPosition(ITokenDescriptor.Coordinate[] memory coordinates, bytes32[] calldata merkleProof) external payable nonReentrant {
        uint256 numCoordinates = coordinates.length;
        if (numCoordinates > MAX_MINT_PER_TX) {
            revert ExceedsMaxMintPerTransaction();
        }
        
        uint256 currentPrice = getCurrentPrice();
        if (merkleProof.length > 0) {
            currentPrice = _getDiscountedCurrentPrice(merkleProof, msg.sender, currentPrice);
        }

        if (msg.value < (currentPrice * numCoordinates)) {
            revert IncorrectPrice();
        }

        uint256 ethToReturn;
        for (uint256 i=0; i < numCoordinates;) {
            bool success = _mintWithChecks(coordinates[i]);
            if (!success) {
                ethToReturn += currentPrice;
            }

            unchecked {
                ++i;
            }
        }

        // return eth for any pieces that failed to mint because a point on the board was already taken when the mint occurred
        if (ethToReturn > 0) {
            payable(msg.sender).safeTransferETH(ethToReturn);
        }
    }

    function _mintWithChecks(ITokenDescriptor.Coordinate memory coordinate) internal returns (bool) {
        if (block.timestamp < config.startTime || _isMintingClosed) {
            revert MintingClosed();
        }
        
        uint256 tokenId = currentTokenId;
        uint256 x = coordinate.x;
        uint256 y = coordinate.y;
        uint256 yIndex = _calculateYGridIndex(y); 

        if (grid[yIndex][x] > 0) {
            return false;
        }

        bytes32 hash = _getCoordinateHash(ITokenDescriptor.Coordinate({x: x, y: y}));
        if (!mintableCoordinates[hash]) {
            revert PositionNotMintable(x, y);
        }

        grid[yIndex][x] = tokenId;
        tokenIdToTokenInfo[tokenId] = ITokenDescriptor.Token({
            initial: ITokenDescriptor.Coordinate({x: x, y: y}),
            current: ITokenDescriptor.Coordinate({x: x, y: y}),
            timestamp: block.timestamp,
            hasReachedEnd: false,
            isLocked: false,
            direction: y >= 12 ? ITokenDescriptor.Direction.DOWN : ITokenDescriptor.Direction.UP,
            numMovements: 0
        });

        if (tokenId != MAX_SUPPLY) {
            currentTokenId++;
        } else {
            _closeMint();
        }
        
        _totalSupply++;
        _removeFromAvailability(coordinateHashToIndex[hash]);
        _mint(msg.sender, tokenId);

        return true;
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

    function getTokens() external view returns (ITokenDescriptor.Token[] memory) {
        ITokenDescriptor.Token[] memory tokens = new ITokenDescriptor.Token[](_totalSupply);

        for(uint256 i=0;i < _totalSupply;) {
            tokens[i] = tokenIdToTokenInfo[i+1];

            unchecked {
                ++i;
            }
        }

        return tokens;
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

        if (!canMove) {
            revert MovementLocked();
        }

        ITokenDescriptor.Token memory token = tokenIdToTokenInfo[tokenId];
        if (token.isLocked) {
            revert OriginPointLocked();
        }

        uint256 x = token.current.x;
        if (xDelta == -1) {
            x--;
        } else if (xDelta == 1) {
            x++;
        }

        uint256 y = token.current.y;
        if (yDelta == -1) {
            y++;
        } else if (yDelta == 1) {
            y--;
        }
        uint256 yGridIndex = _calculateYGridIndex(y);

        if (_isPositionOutOfBounds(x, y)) {
            revert PositionOutOfBounds(x,y);
        }

        if (grid[yGridIndex][x] > 0) {
            revert PositionCurrentlyTaken(x,y);
        }

        grid[_calculateYGridIndex(token.current.y)][token.current.x] = 0;
        grid[yGridIndex][x] = tokenId;

        tokenIdToTokenInfo[tokenId].current = ITokenDescriptor.Coordinate({x: x, y: y});
        tokenIdToTokenInfo[tokenId].hasReachedEnd = ((token.direction == ITokenDescriptor.Direction.UP && y == (NUM_ROWS - 1)) || (token.direction == ITokenDescriptor.Direction.DOWN && y == 1));
        tokenIdToTokenInfo[tokenId].numMovements = ++token.numMovements;
        tokenIdToTokenInfo[tokenId].timestamp = block.timestamp;
    }

    function lockOriginPoint(uint256 tokenId, uint256 x, uint256 y) external {
        if (msg.sender != ownerOf(tokenId)) {
            revert NotTokenOwner();
        }

        if (_isPositionOutOfBounds(x, y)) {
            revert PositionOutOfBounds(x,y);
        }

        uint256 yGridIndex = _calculateYGridIndex(y);
        if (grid[yGridIndex][x] > 0) {
            revert PositionCurrentlyTaken(x,y);
        }

        if (numLockedOriginPoints == MAX_LOCKED_TOKENS) {
            revert MaxLockedOriginPointsAlreadyReached();
        }

        ITokenDescriptor.Token memory token = tokenIdToTokenInfo[tokenId];
        if (!token.hasReachedEnd) {
            revert HasNotReachedEnd();
        }
        
        if (token.isLocked) {
            revert OriginPointLocked();
        }

        grid[_calculateYGridIndex(token.current.y)][token.current.x] = 0;
        grid[yGridIndex][x] = tokenId;

        tokenIdToTokenInfo[tokenId].current = ITokenDescriptor.Coordinate({x: x, y: y});
        tokenIdToTokenInfo[tokenId].timestamp = block.timestamp;
        tokenIdToTokenInfo[tokenId].isLocked = true;
        numLockedOriginPoints++;
    }

    function getAvailableCoordinates() external view returns (ITokenDescriptor.Coordinate[] memory) {
        return availableCoordinates;
    }

    function setInitialAvailableCoordinates(uint256[] calldata positions) external onlyOwner {
        for (uint256 i = 0; i < positions.length; i++) {
            uint256 position = positions[i];
            uint256 x = position % NUM_COLUMNS;
            uint256 y = (position - x) / NUM_ROWS;
            ITokenDescriptor.Coordinate memory coordinate = ITokenDescriptor.Coordinate({x: x, y: y});

            bytes32 hash = _getCoordinateHash(coordinate);
            mintableCoordinates[hash] = true;
            coordinateHashToIndex[hash] = i;
            availableCoordinates.push(coordinate);
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

    function tokensOfOwner(address _owner) public view returns (uint256[] memory) {
        uint256 balance = balanceOf(_owner);
        uint256[] memory tokens = new uint256[](balance);
        uint256 index;
        unchecked {
            for (uint256 i=1; i <= _totalSupply; i++) {
                if (ownerOf(i) == _owner) {
                    tokens[index] = i;
                    index++;
                }
            }
        }
        
        return tokens;
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        if (ownerOf(id) == address(0)) {
            revert NotMinted();
        }

        ITokenDescriptor.Token memory token = tokenIdToTokenInfo[id];
        return descriptor.generateMetadata(id, token);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function updateConfig(
        uint64 startTime,
        uint64 endTime,
        uint256 startPriceInWei,
        uint256 endPriceInWei,
        address payable fundsRecipient
    ) external onlyOwner {
        config.startTime = startTime;
        config.endTime = endTime;
        config.startPriceInWei = startPriceInWei;
        config.endPriceInWei = endPriceInWei;
        config.fundsRecipient = fundsRecipient;
    }

    function setDescriptor(address _descriptor) external onlyOwner {
        descriptor = ITokenDescriptor(_descriptor);
    }

    function updateMerkleRoots(bytes32 _holderRoot, bytes32 _fpMembersRoot) external onlyOwner {
        holdersMerkleRoot = _holderRoot;
        fpMembersMerkleRoot = _fpMembersRoot;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = config.fundsRecipient.call{
            value: balance,
            gas: FUNDS_SEND_GAS_LIMIT
        }("");
        require(success, "Transfer failed.");
    }

    function _closeMint() private {
        _isMintingClosed = true;
        canMove = true;
    }

    function _calculateYGridIndex(uint256 y) private pure returns (uint256) {
        return (NUM_ROWS - 1) - y;
    }

    function _getCoordinateHash(ITokenDescriptor.Coordinate memory coordinate) private pure returns (bytes32) {
        return keccak256(abi.encode(coordinate));
    }

    function _getDiscountedCurrentPrice(bytes32[] calldata merkleProof, address addressToCheck, uint256 currentPrice) private view returns (uint256) {
        bool isHolder = checkMerkleProof(merkleProof, addressToCheck, holdersMerkleRoot);
        bool isFpMember = checkMerkleProof(merkleProof, addressToCheck, fpMembersMerkleRoot);

        if (isFpMember) {
            currentPrice = (currentPrice * 85) / 100; // 15% off
        } else if (isHolder) {
            currentPrice = (currentPrice * 75) / 100; // 25% off
        }
    }

    function _isPositionOutOfBounds(uint256 x, uint256 y) private pure returns (bool) {
        return x < 1 || x >= NUM_COLUMNS - 1 || y < 1 || y >= NUM_ROWS - 1;
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
