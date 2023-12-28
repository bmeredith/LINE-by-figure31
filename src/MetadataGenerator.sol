// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ITokenDescriptor} from "./ITokenDescriptor.sol";
import {JsonWriter} from "solidity-json-writer/JsonWriter.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract MetadataGenerator {
    using JsonWriter for JsonWriter.Json;

    function generateMetadata(uint256 tokenId, ITokenDescriptor.Token calldata token) external view returns (string memory) {
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

        writer = writer.writeEndObject();
    }
}