// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ITokenDescriptor} from "./ITokenDescriptor.sol";
import {JsonWriter} from "solidity-json-writer/JsonWriter.sol";
import {Base64} from '@openzeppelin/contracts/utils/Base64.sol';
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract MetadataGenerator {
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

        writer = writer.writeStringProperty(
            'image',
            string.concat('arweave://')
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

    function _determineImage(ITokenDescriptor.Coordinate calldata coordinate) 
        private
        pure
        returns (uint256) 
    {

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