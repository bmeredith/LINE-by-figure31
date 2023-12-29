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

        uint256 currentImageIndex = _determineCurrentCycleImage(token);
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

    function _determineCurrentCycleImage(ITokenDescriptor.Token calldata token) 
        private
        pure
        returns (uint256) 
    {
        uint256 numDaysPassed = (token.timestamp / 1 days) % 3600;
        uint256 cyclePoint = numDaysPassed % 10;

        // at the origin
        if (cyclePoint % 2 == 0) {
            return _calculateImageIndex(token.current.x, token.current.y);            
        }

        // 1 = left
        // 3 = upper left
        // 5 = up
        // 7 = upper right
        // 9 = right
        uint256 x;
        uint256 y;
        if (cyclePoint == 1) {
            x = token.current.x - 1;
            y = token.current.y;
        } else if (cyclePoint == 3) {
            x = token.current.x - 1;
            y = token.current.y + 1;
        } else if (cyclePoint == 5) {
            x = token.current.x;
            y = token.current.y + 1;
        } else if (cyclePoint == 7) {
            x = token.current.x + 1;
            y = token.current.y + 1;
        } else if (cyclePoint == 9) {
            x = token.current.x + 1;
            y = token.current.y;
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