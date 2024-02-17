// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Constants} from "./Constants.sol";
import {ITokenDescriptor} from "./ITokenDescriptor.sol";
import {JsonWriter} from "solidity-json-writer/JsonWriter.sol";
import {Base64} from '@openzeppelin/contracts/utils/Base64.sol';
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract Descriptor is ITokenDescriptor, Constants {
    using JsonWriter for JsonWriter.Json;

    function generateMetadata(uint256 tokenId, Token calldata token) 
        external 
        view 
        returns (string memory) 
    {
        JsonWriter.Json memory writer;
        writer = writer.writeStartObject();

        writer = writer.writeStringProperty(
            'name',
            string.concat('LINE ', Strings.toString(tokenId))
        );

        writer = writer.writeStringProperty(
            'description',
            'LINE is a photographic series of 250 tokens placed within a synthetic landscape. Tokens act like camera lenses, where location also influences perception. The images in LINE are captured using a digital camera combined with ultra-telephoto lenses.'
        );

        writer = writer.writeStringProperty(
            'external_url',
            'https://line.fingerprintsdao.xyz'
        );

        uint256 currentImageIndex = _getCurrentPanoramicImageIndex(token);
        writer = writer.writeStringProperty(
            'image',
            string.concat('ar://Y-05cY1jiKkVn9aCL3Di3sOWfCUZRPLaoASs0LYJOsU/', Strings.toString(currentImageIndex), '.jpg')
        );

        writer = _generateAttributes(writer, token);

        writer = writer.writeEndObject();

        return string(
            abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(abi.encodePacked(writer.value))
            )
        );
    }

    function _determineCurrentImagePoint(Token calldata token)
        private
        view
        returns (uint256, uint256)
    {
        uint256 numDaysPassed = (block.timestamp - token.timestamp) / 1 days;
        uint256 numPanoramicPoints;

        if (!token.isLocked) {
            numPanoramicPoints = 10; // 180° panoramic view
        } else {
            numPanoramicPoints = 16; // 360° panoramic view
        }

        uint256 panoramicPoint = numDaysPassed % numPanoramicPoints;

        // is at the origin point for the day
        if (panoramicPoint % 2 == 0) {
            return (token.current.x, token.current.y);            
        }

        uint256 x;
        uint256 y;

        // full panoramic view
        // 1 = west
        // 3 = northwest
        // 5 = north
        // 7 = northeast
        // 9 = east
        // 11 = southeast
        // 13 = south
        // 15 = southwest
        if (token.isLocked) {
            if (panoramicPoint == 1) {
                x = token.current.x - 1;
                y = token.current.y;
            } else if (panoramicPoint == 3) {
                x = token.current.x - 1;
                y = token.current.y + 1;
            } else if (panoramicPoint == 5) {
                x = token.current.x;
                y = token.current.y + 1;
            } else if (panoramicPoint == 7) {
                x = token.current.x + 1;
                y = token.current.y + 1;
            } else if (panoramicPoint == 9) {
                x = token.current.x + 1;
                y = token.current.y;
            } else if (panoramicPoint == 11) {
                x = token.current.x + 1;
                y = token.current.y - 1;
            } else if (panoramicPoint == 13) {
                x = token.current.x;
                y = token.current.y - 1;
            } else if (panoramicPoint == 15) {
                x = token.current.x - 1;
                y = token.current.y - 1;
            }

            return (x,y);
        }

        // 1 = look west
        // 3 = look southwest
        // 5 = look south
        // 7 = look southeast
        // 9 = look east
        if (token.direction == Direction.DOWN) {
            if (panoramicPoint == 1) {
                x = token.current.x - 1;
                y = token.current.y;
            } else if (panoramicPoint == 3) {
                x = token.current.x - 1;
                y = token.current.y - 1;
            } else if (panoramicPoint == 5) {
                x = token.current.x;
                y = token.current.y - 1;
            } else if (panoramicPoint == 7) {
                x = token.current.x + 1;
                y = token.current.y - 1;
            } else if (panoramicPoint == 9) {
                x = token.current.x + 1;
                y = token.current.y;
            }
        }
        
        // 1 = look west
        // 3 = look northwest
        // 5 = look north
        // 7 = look northeast
        // 9 = look east
        if (token.direction == Direction.UP) {
            if (panoramicPoint == 1) {
                x = token.current.x - 1;
                y = token.current.y;
            } else if (panoramicPoint == 3) {
                x = token.current.x - 1;
                y = token.current.y + 1;
            } else if (panoramicPoint == 5) {
                x = token.current.x;
                y = token.current.y + 1;
            } else if (panoramicPoint == 7) {
                x = token.current.x + 1;
                y = token.current.y + 1;
            } else if (panoramicPoint == 9) {
                x = token.current.x + 1;
                y = token.current.y;
            }
        }

        return (x,y);
    }

    function _getCurrentPanoramicImageIndex(Token calldata token) 
        private
        view
        returns (uint256) 
    {
        (uint256 x, uint256 y) = _determineCurrentImagePoint(token);
        return _calculateImageIndex(x, y);
    }
    
    function _calculateImageIndex(uint256 x, uint256 y)
        private
        pure
        returns (uint256) 
    {
        uint256 yIndex = (NUM_ROWS - 1) - y;
        return ((NUM_ROWS - yIndex - 1) * NUM_COLUMNS) + x;
    }

    function _generateAttributes(JsonWriter.Json memory _writer, Token calldata token) 
        private 
        view 
        returns (JsonWriter.Json memory writer)
    {
        writer = _writer.writeStartArray('attributes');

        (uint256 imagePointX, uint256 imagePointY) = _determineCurrentImagePoint(token);
        writer = _addStringAttribute(writer, 'Origin Point', string.concat(Strings.toString(token.current.x), ',', Strings.toString(token.current.y)));
        writer = _addStringAttribute(writer, 'Image Point', string.concat(Strings.toString(imagePointX), ',', Strings.toString(imagePointY)));
        writer = _addStringAttribute(writer, 'Type', token.direction == Direction.UP ? 'Up' : 'Down');
        writer = _addStringAttribute(writer, 'Starting Point', string.concat(Strings.toString(token.initial.x), ',', Strings.toString(token.initial.y)));
        writer = _addStringAttribute(writer, 'Has Reached End', token.hasReachedEnd == true ? 'Yes' : 'No');
        writer = _addStringAttribute(writer, 'Is Locked', token.isLocked == true ? 'Yes' : 'No');
        writer = _addStringAttribute(writer, 'Movements', Strings.toString(token.numMovements));

        writer = writer.writeEndArray();
    }

    function _addStringAttribute(
        JsonWriter.Json memory _writer,
        string memory key,
        string memory value
    ) private pure returns (JsonWriter.Json memory writer) {
        writer = _writer.writeStartObject();
        writer = writer.writeStringProperty('trait_type', key);
        writer = writer.writeStringProperty('value', value);
        writer = writer.writeEndObject();
    }
}