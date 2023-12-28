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
        // have a field that is where the origin point is pointing to for that day
        Coordinate initial;
        Coordinate current;
        uint256 timestamp;
        bool hasReachedEnd;
        Direction direction;
        uint256 numMovements;
    }
}