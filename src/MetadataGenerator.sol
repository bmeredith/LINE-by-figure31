// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Constants} from "./Constants.sol";
import {ITokenDescriptor} from "./ITokenDescriptor.sol";
import {JsonWriter} from "solidity-json-writer/JsonWriter.sol";
import {Base64} from '@openzeppelin/contracts/utils/Base64.sol';
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract MetadataGenerator is Constants {
    using JsonWriter for JsonWriter.Json;

    function generateMetadata(uint256 tokenId, ITokenDescriptor.Token calldata token) 
        external 
        pure 
        returns (string memory) 
    {
        JsonWriter.Json memory writer;
        writer = writer.writeStartObject();

        writer = writer.writeStringProperty(
            'name',
            string.concat('TBD ', Strings.toString(tokenId))
        );

        writer = writer.writeStringProperty(
            'description',
            'DESCRIPTION HERE'
        );

        writer = writer.writeStringProperty(
            'external_url',
            'https://temp'
        );

        uint256 currentImageIndex = _determineCurrentPanoramicImage(token);
        writer = writer.writeStringProperty(
            'image',
            string.concat('arweave://', Strings.toString(currentImageIndex))
        );

        writer = _generateAttributes(writer);

        writer = writer.writeEndObject();

        return string(
            abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(abi.encodePacked(writer.value))
            )
        );
    }

    function _determineCurrentPanoramicImage(ITokenDescriptor.Token calldata token) 
        private
        pure
        returns (uint256) 
    {
        uint256 numDaysPassed = (token.timestamp / 1 days) % 3600;
        uint256 numPanoramicPoints;

        if (!token.isLocked) {
            numPanoramicPoints = 10; // 180° panoramic view
        } else {
            numPanoramicPoints = 16; // 360° panoramic view
        }

        uint256 panoramicPoint = numDaysPassed % numPanoramicPoints;

        // at the origin point for the day
        if (panoramicPoint % 2 == 0) {
            return _calculateImageIndex(token.current.x, token.current.y);            
        }

        uint256 x;
        uint256 y;
        // 1 = west
        // 3 = northwest
        // 5 = north
        // 7 = northeast
        // 9 = east
        // 11 = southeast
        // 13 = south
        // 15 = southwest
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
        } else if (panoramicPoint == 11) {
            x = token.current.x + 1;
            y = token.current.y + 1;
        } else if (panoramicPoint == 13) {
            x = token.current.x;
            y = token.current.y + 1;
        } else if (panoramicPoint == 15) {
            x = token.current.x - 1;
            y = token.current.y + 1;
        }

        return _calculateImageIndex(x, y);
    }
    
    function _calculateImageIndex(uint256 x, uint256 y)
        private
        pure
        returns (uint256) 
    {
        return (y * NUM_ROWS) + x;
    }

    function _generateAttributes(JsonWriter.Json memory _writer) 
        private 
        pure 
        returns (JsonWriter.Json memory writer)
    {
        writer = _writer.writeStartArray('attributes');

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