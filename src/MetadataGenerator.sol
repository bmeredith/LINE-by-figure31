// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ITokenDescriptor} from "./ITokenDescriptor.sol";
import {JsonWriter} from "solidity-json-writer/JsonWriter.sol";

contract MetadataGenerator {
    using JsonWriter for JsonWriter.Json;

    function generateMetadata() external view returns (string memory) {
        
    }
}