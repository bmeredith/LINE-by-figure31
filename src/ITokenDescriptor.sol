// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface ITokenDescriptor {
    enum Direction {
        UP,
        DOWN
    }

    struct Coordinate {
        uint256 x;
        uint256 y;
    }

    struct Token {
        Coordinate initial;
        Coordinate current;
        uint256 timestamp;
        bool hasReachedEnd;
        bool isStar;
        Direction direction;
        uint256 numMovements;
    }

    function generateMetadata(uint256 tokenId, ITokenDescriptor.Token calldata token)
        external
        view
        returns (string memory);
}