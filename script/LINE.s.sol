// SPDX-License-Identifier: MIT
pragma solidity =0.8.23;

import {ITokenDescriptor} from "../src/ITokenDescriptor.sol";
import {Descriptor} from "../src/Descriptor.sol";
import {LINE} from "../src/LINE.sol";
import {Script} from "forge-std/Script.sol";

abstract contract Deploy is Script {
    function _deploy() internal {
        vm.startBroadcast();
        Descriptor descriptor = new Descriptor();
        LINE line = new LINE(address(descriptor));

        line.setInitialAvailableCoordinates(_getMintableCoordinates());
        line.updateConfig(
            uint64(1704369600), uint64(1704373200), 1000000000000000000, 1000000000000000
        );
        vm.stopBroadcast();
    }

    uint256[] coordinates;     
    function _getMintableCoordinates() private returns (uint256[] memory) {   
        for(uint256 i=601;i < 624;i++) {
            coordinates.push(i);
        }

        for(uint256 i=526;i < 549;i++) {
            coordinates.push(i);
        }

        return coordinates;
    }

    // function _getMintableCoordinates() private view returns (ITokenDescriptor.Coordinate[] memory) {
    //     ITokenDescriptor.Coordinate[] memory coordinates = new ITokenDescriptor.Coordinate[](20);
    //     for (uint256 i = 0; i < 20; i++) {
    //         uint256 randomX;
    //         uint256 randomY;
    //         randomX = uint256(keccak256(abi.encode(block.timestamp, i))) % 24 + 1;
    //         randomY = uint256(keccak256(abi.encode(block.timestamp, i + 20))) % 24 + 1;
    //         coordinates[i] = ITokenDescriptor.Coordinate({x: randomX, y: randomY});
    //     }
    //     return coordinates;
    // }
}

contract DeployMainnet is Deploy {
    function run() external {
        _deploy();
    }
}

contract DeploySepolia is Deploy {
    function run() external {
        _deploy();
    }
}

contract DeployLocal is Deploy {
    function run() external {
        _deploy();
    }
}

contract ChangeSetup is Script {
    function run() external {
        vm.startBroadcast();
        LINE line = LINE(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);
        line.updateConfig(
            uint64(block.timestamp) + 60 * 2, uint64(block.timestamp) + 60 * 60, 1000000000000000000, 200000000000000000
        );
        vm.stopBroadcast();
    }
}
