// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title LINE
///
/// @author figure31.eth
/// @author wilt.eth
import {Constants} from "./Constants.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Descriptor} from "./Descriptor.sol";
import {ITokenDescriptor} from "./ITokenDescriptor.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

/// @dev Thrown when too many tokens are attempted to be minted within a single transaction.
error ExceedsMaxMintPerTransaction();

/// @dev Thrown when a token has not yet reached the end of the grid.
error HasNotReachedEnd();

/// @dev Thrown when the eth passed to purchase a token is incorrect.
error IncorrectPrice();

/// @dev Thrown when attempting to move in a direction opposite of the token's designated direction.
error InvalidDirection();

/// @dev Thrown when the max number of star tokens has already occurred.
error MaxStarTokensReached();

/// @dev Thrown when attempting to mint a token after minting has closed.
error MintingClosed();

/// @dev Thrown when attempting to move a token and the ability to move tokens has not started yet.
error MovementLocked();

/// @dev Thrown when checking the owner or approved address for a non-existent NFT.
error NotMinted();

/// @dev Thrown when checking that the caller is not the owner of the NFT.
error NotTokenOwner();

/// @dev Thrown when attempting to move a token that is already locked and is a star token.
error OriginPointLocked();

/// @dev Thrown when attempting to move a token to a place on the grid that is already taken.
error PositionCurrentlyTaken(uint256 x, uint256 y);

/// @dev Thrown when attempting to mint a token to a place on the grid that was not marked to be minted from.
error PositionNotMintable(uint256 x, uint256 y);

/// @dev Thrown when attempting to move a token to a place that is outside the bounds of the grid.
error PositionOutOfBounds(uint256 x, uint256 y);

contract LINE is ERC721, Ownable2Step, ReentrancyGuard, Constants {

    using SafeTransferLib for address payable;

    /// @dev Struct containing the details of the Dutch auction
    struct SalesConfig {
        // start time of the auction
        uint64 startTime;

        // end time of the auction
        uint64 endTime;
        
        // initial price of the Dutch auction
        uint256 startPriceInWei;

        // resting price of the Dutch auction
        uint256 endPriceInWei;

        // recepient of the funds from the Dutch auction
        address payable fundsRecipient;
    }

    /// @dev The maximum allowed number of star tokens.
    uint256 public constant MAX_STAR_TOKENS = 25;

    /// @dev The maximum allowed number of tokens to be minted within a single transaction.
    uint256 public constant MAX_MINT_PER_TX = 5;
    
    /// @dev The maximum number of tokens to be minted.
    uint256 public constant MAX_SUPPLY = 250;
    uint256 internal immutable FUNDS_SEND_GAS_LIMIT = 210_000;

    /// @dev The merkle root for collectors/holders.
    bytes32 public holdersMerkleRoot;

    /// @dev The merkle root for members of FingerprintsDAO.
    bytes32 public fpMembersMerkleRoot;

    /// @dev Keeps track of the current token id.
    uint256 public currentTokenId = 1;
    
    /// @dev Keeps track of the number of tokens that have become star tokens.
    uint256 public numStarTokens;
    
    /// @dev The flag to determine if tokens have the ability to move.
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
    
    /// @dev Mints a token at a random position on the grid.
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

    /// @dev Mints a token at the specified on the grid.
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

    /// @dev Ends the ability to mint.
    function closeMint() external onlyOwner {
        _closeMint();
    }

    /// @dev Moves a token one spot to the north on the cartesian grid.
    function moveNorth(uint256 tokenId) external {
        if (tokenIdToTokenInfo[tokenId].direction != ITokenDescriptor.Direction.UP) {
            revert InvalidDirection();
        }

        _move(tokenId, 0, -1);
    }

    /// @dev Moves a token one spot to the northwest on the cartesian grid.
    function moveNorthwest(uint256 tokenId) external {
        if (tokenIdToTokenInfo[tokenId].direction != ITokenDescriptor.Direction.UP) {
            revert InvalidDirection();
        }

        _move(tokenId, -1, -1);
    }

    /// @dev Moves a token one spot to the northeast on the cartesian grid.
    function moveNortheast(uint256 tokenId) external {
        if (tokenIdToTokenInfo[tokenId].direction != ITokenDescriptor.Direction.UP) {
            revert InvalidDirection();
        }

        _move(tokenId, 1, -1);
    }

    /// @dev Moves a token one spot to the south on the cartesian grid.
    function moveSouth(uint256 tokenId) external {
        if (tokenIdToTokenInfo[tokenId].direction != ITokenDescriptor.Direction.DOWN) {
            revert InvalidDirection();
        }

        _move(tokenId, 0, 1);
    }

    /// @dev Moves a token one spot to the southwest on the cartesian grid.
    function moveSouthwest(uint256 tokenId) external {
        if (tokenIdToTokenInfo[tokenId].direction != ITokenDescriptor.Direction.DOWN) {
            revert InvalidDirection();
        }

        _move(tokenId, -1, 1);
    }

    /// @dev Moves a token one spot to the southeast on the cartesian grid.
    function moveSoutheast(uint256 tokenId) external {
        if (tokenIdToTokenInfo[tokenId].direction != ITokenDescriptor.Direction.DOWN) {
            revert InvalidDirection();
        }

        _move(tokenId, 1, 1);
    }

    /// @dev Moves a token one spot to the west on the cartesian grid.
    function moveWest(uint256 tokenId) external {
        _move(tokenId, -1, 0);
    }

    /// @dev Moves a token one spot to the east on the cartesian grid.
    function moveEast(uint256 tokenId) external {
        _move(tokenId, 1, 0);
    }

    /// @dev Converts a token to be a star token and locks their token at the given position.
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
            revert MaxStarTokensReached();
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

    /// @dev Sets the coordinates that are available to minted.
    function setInitialAvailableCoordinates(ITokenDescriptor.Coordinate[] calldata positions) external onlyOwner {
        for (uint256 i = 0; i < positions.length; i++) {
            ITokenDescriptor.Coordinate memory coordinate = ITokenDescriptor.Coordinate({x: positions[i].x, y: positions[i].y});

            bytes32 hash = _getCoordinateHash(coordinate);
            _mintableCoordinates[hash] = true;
            _coordinateHashToIndex[hash] = i;
            _availableCoordinates.push(coordinate);
        }
    }

    /// @dev Updates the details of the Dutch auction.
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

    /// @dev Sets the address of the descriptor.
    function setDescriptor(address _descriptor) external onlyOwner {
        descriptor = ITokenDescriptor(_descriptor);
    }

    /// @dev Updates the merkle roots
    function updateMerkleRoots(bytes32 _holdersRoot, bytes32 _fpMembersRoot) external onlyOwner {
        holdersMerkleRoot = _holdersRoot;
        fpMembersMerkleRoot = _fpMembersRoot;
    }

    /// @dev Withdraws the eth from the contract to the set funds receipient.
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = config.fundsRecipient.call{
            value: balance,
            gas: FUNDS_SEND_GAS_LIMIT
        }("");
        require(success, "Transfer failed.");
    }

    /// @dev Returns the available coordinates that are still available for mint.
    function getAvailableCoordinates() external view returns (ITokenDescriptor.Coordinate[] memory) {
        return _availableCoordinates;
    }

    /// @dev Returns the cartesian grid of where tokens are placed at within the grid.
    function getGrid() external view returns (uint256[NUM_COLUMNS][NUM_ROWS] memory) {
        return _grid;
    }

    /// @dev Returns the details of a token.
    function getToken(uint256 tokenId) external view returns (ITokenDescriptor.Token memory) {
        return tokenIdToTokenInfo[tokenId];
    }

    /// @dev Returns the details of all tokens.
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
    
    /// @dev Returns if a wallet address/proof is part of the given merkle root.
    function checkMerkleProof(
        bytes32[] calldata merkleProof,
        address _address,
        bytes32 _root
    ) public pure returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(_address));
        return MerkleProof.verify(merkleProof, _root, leaf);
    }

    /// @dev Returns the current price of the Dutch auction.
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

    /// @dev Returns the token ids that a wallet has ownership of.
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

    /// @dev Returns the tokenURI of the given token id.
    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        if (ownerOf(id) == address(0)) {
            revert NotMinted();
        }

        ITokenDescriptor.Token memory token = tokenIdToTokenInfo[id];
        return descriptor.generateMetadata(id, token);
    }

    /// @dev Returns the total supply.
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
