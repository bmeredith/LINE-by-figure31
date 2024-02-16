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
    
    uint256 public constant MAX_STAR_TOKENS = 25;
    uint256 public constant MAX_MINT_PER_TX = 5;
    uint256 public constant MAX_SUPPLY = 250;
    uint256 internal immutable FUNDS_SEND_GAS_LIMIT = 210_000;

    bytes32 public holdersMerkleRoot;
    bytes32 public fpMembersMerkleRoot;

    uint256 public currentTokenId = 1;
    uint256 public numStarTokens;
    bool public canMove;
    bool private _isMintingClosed;
    uint256 private  _totalSupply;

    ITokenDescriptor public descriptor;
    SalesConfig public config;

    uint256[NUM_COLUMNS][NUM_ROWS] internal _grid;
    ITokenDescriptor.Coordinate[] internal _availableCoordinates;
    mapping(bytes32 => uint256) internal _coordinateHashToIndex;
    mapping(bytes32 => bool) internal _mintableCoordinates;
    mapping(uint256 => ITokenDescriptor.Token) public tokenIdToTokenInfo;

    constructor(address _descriptor) ERC721("LINE", "LINE") Ownable(msg.sender) {
        descriptor = ITokenDescriptor(_descriptor);
        config.startTime = uint64(1708538400);
        config.endTime = uint64(1708538400 + 3600);
        config.startPriceInWei = 1000000000000000000; // 1 eth
        config.endPriceInWei = 150000000000000000; // .15 eth
        config.fundsRecipient = payable(msg.sender);
    }

    function mintRandom(uint256 quantity, bytes32[] calldata merkleProof) external payable nonReentrant {
        if (block.timestamp < config.startTime || _isMintingClosed) {
            revert MintingClosed();
        }

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
            bool success;
            if (_availableCoordinates.length == 0) {
                success = false;
            } else {
                ITokenDescriptor.Coordinate memory coordinateToMint = _availableCoordinates[0];
                success = _mintWithChecks(coordinateToMint, msg.sender);
            }

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
        if (block.timestamp < config.startTime || _isMintingClosed) {
            revert MintingClosed();
        }

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
            bool success = _mintWithChecks(coordinates[i], msg.sender);
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

    function artistMint(address receiver, ITokenDescriptor.Coordinate[] memory coordinates) external onlyOwner {
        if (_isMintingClosed) {
            revert MintingClosed();
        }

        uint256 numCoordinates = coordinates.length;
        for (uint256 i=0; i < numCoordinates;) {
            _mintWithChecks(coordinates[i], receiver);

            unchecked {
                ++i;
            }
        }
    }

    function closeMint() external onlyOwner {
        _closeMint();
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

    function lockOriginPoint(uint256 tokenId, uint256 x, uint256 y) external {
        if (msg.sender != ownerOf(tokenId)) {
            revert NotTokenOwner();
        }

        ITokenDescriptor.Token memory token = tokenIdToTokenInfo[tokenId];
        if (!_isPositionWithinBounds(x, y, token.direction)) {
            revert PositionOutOfBounds(x,y);
        }

        uint256 yGridIndex = _calculateYGridIndex(y);
        if (_grid[yGridIndex][x] > 0) {
            revert PositionCurrentlyTaken(x,y);
        }

        if (numStarTokens == MAX_STAR_TOKENS) {
            revert MaxLockedOriginPointsAlreadyReached();
        }

        if (!token.hasReachedEnd) {
            revert HasNotReachedEnd();
        }
        
        if (token.isLocked) {
            revert OriginPointLocked();
        }

        _grid[_calculateYGridIndex(token.current.y)][token.current.x] = 0;
        _grid[yGridIndex][x] = tokenId;

        tokenIdToTokenInfo[tokenId].current = ITokenDescriptor.Coordinate({x: x, y: y});
        tokenIdToTokenInfo[tokenId].timestamp = block.timestamp;
        tokenIdToTokenInfo[tokenId].isLocked = true;
        numStarTokens++;
    }

    function setInitialAvailableCoordinates(uint256[] calldata positions) external onlyOwner {
        for (uint256 i = 0; i < positions.length; i++) {
            uint256 position = positions[i];
            uint256 x = position % NUM_COLUMNS;
            uint256 y = (position - x) / NUM_ROWS;
            ITokenDescriptor.Coordinate memory coordinate = ITokenDescriptor.Coordinate({x: x, y: y});

            bytes32 hash = _getCoordinateHash(coordinate);
            _mintableCoordinates[hash] = true;
            _coordinateHashToIndex[hash] = i;
            _availableCoordinates.push(coordinate);
        }
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

    function getAvailableCoordinates() external view returns (ITokenDescriptor.Coordinate[] memory) {
        return _availableCoordinates;
    }

    function getGrid() external view returns (uint256[NUM_COLUMNS][NUM_ROWS] memory) {
        return _grid;
    }

    function getToken(uint256 tokenId) external view returns (ITokenDescriptor.Token memory) {
        return tokenIdToTokenInfo[tokenId];
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
    
    function checkMerkleProof(
        bytes32[] calldata merkleProof,
        address _address,
        bytes32 _root
    ) public pure returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(_address));
        return MerkleProof.verify(merkleProof, _root, leaf);
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

    function _mintWithChecks(ITokenDescriptor.Coordinate memory coordinate, address receiver) internal returns (bool) {        
        uint256 tokenId = currentTokenId;
        uint256 x = coordinate.x;
        uint256 y = coordinate.y;
        uint256 yIndex = _calculateYGridIndex(y); 

        if (_grid[yIndex][x] > 0) {
            return false;
        }

        bytes32 hash = _getCoordinateHash(ITokenDescriptor.Coordinate({x: x, y: y}));
        if (!_mintableCoordinates[hash]) {
            revert PositionNotMintable(x, y);
        }

        _grid[yIndex][x] = tokenId;
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
        _removeFromAvailability(_coordinateHashToIndex[hash]);
        _mint(receiver, tokenId);

        return true;
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

        if (!_isPositionWithinBounds(x, y, token.direction)) {
            revert PositionOutOfBounds(x,y);
        }

        uint256 yGridIndex = _calculateYGridIndex(y);
        if (_grid[yGridIndex][x] > 0) {
            revert PositionCurrentlyTaken(x,y);
        }

        _grid[_calculateYGridIndex(token.current.y)][token.current.x] = 0;
        _grid[yGridIndex][x] = tokenId;

        tokenIdToTokenInfo[tokenId].current = ITokenDescriptor.Coordinate({x: x, y: y});
        tokenIdToTokenInfo[tokenId].hasReachedEnd = ((token.direction == ITokenDescriptor.Direction.UP && y == (NUM_ROWS - 2)) || (token.direction == ITokenDescriptor.Direction.DOWN && y == 1));
        tokenIdToTokenInfo[tokenId].numMovements = ++token.numMovements;
        tokenIdToTokenInfo[tokenId].timestamp = block.timestamp;
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
        
        if (isHolder) {
            currentPrice = (currentPrice * 75) / 100; // 25% off
        } else if (isFpMember) {
            currentPrice = (currentPrice * 85) / 100; // 15% off
        }

        return currentPrice;
    }

    function _isPositionWithinBounds(uint256 x, uint256 y, ITokenDescriptor.Direction tokenDirection) private pure returns (bool) {
        if (x < 1 || x >= NUM_COLUMNS - 1) {
            return false;
        }

        if (tokenDirection == ITokenDescriptor.Direction.DOWN) {
            return y > 0;
        } else {
            return y < NUM_ROWS - 1;
        }
    }

    function _removeFromAvailability(uint256 index) private {
        uint256 lastCoordinateIndex = _availableCoordinates.length - 1;
        ITokenDescriptor.Coordinate memory lastCoordinate = _availableCoordinates[lastCoordinateIndex];
        ITokenDescriptor.Coordinate memory coordinateToBeRemoved = _availableCoordinates[index];

        _availableCoordinates[index] = lastCoordinate;
        _coordinateHashToIndex[_getCoordinateHash(lastCoordinate)] = index;
        delete _coordinateHashToIndex[_getCoordinateHash(coordinateToBeRemoved)];
        _availableCoordinates.pop();
    }
}
