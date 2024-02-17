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
            uint64(1708198200), uint64(1708201800), 1000000000000000000, 1000000000000000, payable(msg.sender)
        );
        vm.stopBroadcast();
    }

    ITokenDescriptor.Coordinate[] coordinates;

    function _getMintableCoordinates() private returns (ITokenDescriptor.Coordinate[] memory) {
        for (uint256 i = 1; i < 24; i++) {
            coordinates.push(ITokenDescriptor.Coordinate({x: i, y: 24}));
        }

        for (uint256 i = 1; i < 24; i++) {
            coordinates.push(ITokenDescriptor.Coordinate({x: i, y: 22}));
        }

        for (uint256 i = 1; i < 24; i++) {
            coordinates.push(ITokenDescriptor.Coordinate({x: i, y: 0}));
        }

        for (uint256 i = 1; i < 24; i++) {
            coordinates.push(ITokenDescriptor.Coordinate({x: i, y: 2}));
        }

        return coordinates;
    }

    // function _getMintableCoordinates() private returns (uint256[] memory) {
    //     uint256 coord;
    //     for (uint256 i = 0; i < 5; i++) {
    //         coord = uint256(keccak256(abi.encode(block.timestamp, i))) % 626;
    //         while (coord % 25 == 0) {
    //             coord = (coord + 1) % 626;
    //         }
    //         coordinates.push(coord);
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
            uint64(block.timestamp) + 60 * 2,
            uint64(block.timestamp) + 60 * 60,
            1000000000000000000,
            200000000000000000,
            payable(msg.sender)
        );
        vm.stopBroadcast();
    }
}

contract SetMerkleRoots is Script {
    function run() external {
        vm.startBroadcast();
        LINE line = LINE(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);
        line.updateMerkleRoots(
            0x28047ed34121b81cceb2b9f56917953ba4bef2fa9c3ba9936343c6846009a2a8,
            0xbe3cc57529233275f6526734cde40e0d719022504650320a8908e16d231871db
        );
        vm.stopBroadcast();
    }
}

contract CloseMint is Script {
    function run() external {
        vm.startBroadcast();
        LINE line = LINE(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);
        line.closeMint();
        vm.stopBroadcast();
    }
}