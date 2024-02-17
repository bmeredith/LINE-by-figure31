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
        coordinates.push(ITokenDescriptor.Coordinate({x:17, y:7}));
        coordinates.push(ITokenDescriptor.Coordinate({x:11, y:9}));
        coordinates.push(ITokenDescriptor.Coordinate({x:1, y:11}));
        coordinates.push(ITokenDescriptor.Coordinate({x:8, y:9}));
        coordinates.push(ITokenDescriptor.Coordinate({x:7, y:5}));
        coordinates.push(ITokenDescriptor.Coordinate({x:14, y:17}));
        coordinates.push(ITokenDescriptor.Coordinate({x:7, y:7}));
        coordinates.push(ITokenDescriptor.Coordinate({x:6, y:4}));
        coordinates.push(ITokenDescriptor.Coordinate({x:6, y:18}));
        coordinates.push(ITokenDescriptor.Coordinate({x:15, y:21}));
        coordinates.push(ITokenDescriptor.Coordinate({x:13, y:24}));
        coordinates.push(ITokenDescriptor.Coordinate({x:6, y:9}));
        coordinates.push(ITokenDescriptor.Coordinate({x:3, y:11}));
        coordinates.push(ITokenDescriptor.Coordinate({x:20, y:14}));
        coordinates.push(ITokenDescriptor.Coordinate({x:6, y:17}));
        coordinates.push(ITokenDescriptor.Coordinate({x:20, y:20}));
        coordinates.push(ITokenDescriptor.Coordinate({x:18, y:4}));
        coordinates.push(ITokenDescriptor.Coordinate({x:12, y:21}));
        coordinates.push(ITokenDescriptor.Coordinate({x:18, y:11}));
        coordinates.push(ITokenDescriptor.Coordinate({x:6, y:1}));
        coordinates.push(ITokenDescriptor.Coordinate({x:23, y:3}));
        coordinates.push(ITokenDescriptor.Coordinate({x:4, y:8}));
        coordinates.push(ITokenDescriptor.Coordinate({x:21, y:10}));
        coordinates.push(ITokenDescriptor.Coordinate({x:12, y:18}));
        coordinates.push(ITokenDescriptor.Coordinate({x:23, y:11}));
        coordinates.push(ITokenDescriptor.Coordinate({x:15, y:5}));
        coordinates.push(ITokenDescriptor.Coordinate({x:2, y:19}));
        coordinates.push(ITokenDescriptor.Coordinate({x:3, y:17}));
        coordinates.push(ITokenDescriptor.Coordinate({x:1, y:13}));
        coordinates.push(ITokenDescriptor.Coordinate({x:3, y:10}));
        coordinates.push(ITokenDescriptor.Coordinate({x:2, y:16}));
        coordinates.push(ITokenDescriptor.Coordinate({x:10, y:10}));
        coordinates.push(ITokenDescriptor.Coordinate({x:23, y:15}));
        coordinates.push(ITokenDescriptor.Coordinate({x:1, y:1}));
        coordinates.push(ITokenDescriptor.Coordinate({x:9, y:4}));
        coordinates.push(ITokenDescriptor.Coordinate({x:11, y:0}));
        coordinates.push(ITokenDescriptor.Coordinate({x:14, y:13}));
        coordinates.push(ITokenDescriptor.Coordinate({x:6, y:5}));
        coordinates.push(ITokenDescriptor.Coordinate({x:4, y:3}));
        coordinates.push(ITokenDescriptor.Coordinate({x:11, y:14}));
        coordinates.push(ITokenDescriptor.Coordinate({x:16, y:20}));
        coordinates.push(ITokenDescriptor.Coordinate({x:7, y:13}));
        coordinates.push(ITokenDescriptor.Coordinate({x:22, y:1}));
        coordinates.push(ITokenDescriptor.Coordinate({x:6, y:3}));
        coordinates.push(ITokenDescriptor.Coordinate({x:15, y:20}));
        coordinates.push(ITokenDescriptor.Coordinate({x:5, y:24}));
        coordinates.push(ITokenDescriptor.Coordinate({x:16, y:23}));
        coordinates.push(ITokenDescriptor.Coordinate({x:22, y:23}));
        coordinates.push(ITokenDescriptor.Coordinate({x:19, y:16}));
        coordinates.push(ITokenDescriptor.Coordinate({x:12, y:8}));
        coordinates.push(ITokenDescriptor.Coordinate({x:16, y:8}));
        coordinates.push(ITokenDescriptor.Coordinate({x:15, y:14}));
        coordinates.push(ITokenDescriptor.Coordinate({x:12, y:3}));
        coordinates.push(ITokenDescriptor.Coordinate({x:6, y:11}));
        coordinates.push(ITokenDescriptor.Coordinate({x:21, y:2}));
        coordinates.push(ITokenDescriptor.Coordinate({x:14, y:2}));
        coordinates.push(ITokenDescriptor.Coordinate({x:11, y:21}));
        coordinates.push(ITokenDescriptor.Coordinate({x:12, y:13}));
        coordinates.push(ITokenDescriptor.Coordinate({x:12, y:11}));
        coordinates.push(ITokenDescriptor.Coordinate({x:12, y:16}));
        coordinates.push(ITokenDescriptor.Coordinate({x:3, y:7}));
        coordinates.push(ITokenDescriptor.Coordinate({x:3, y:19}));
        coordinates.push(ITokenDescriptor.Coordinate({x:18, y:0}));
        coordinates.push(ITokenDescriptor.Coordinate({x:19, y:20}));
        coordinates.push(ITokenDescriptor.Coordinate({x:1, y:0}));
        coordinates.push(ITokenDescriptor.Coordinate({x:1, y:3}));
        coordinates.push(ITokenDescriptor.Coordinate({x:23, y:17}));
        coordinates.push(ITokenDescriptor.Coordinate({x:4, y:17}));
        coordinates.push(ITokenDescriptor.Coordinate({x:21, y:8}));
        coordinates.push(ITokenDescriptor.Coordinate({x:1, y:15}));
        coordinates.push(ITokenDescriptor.Coordinate({x:17, y:3}));
        coordinates.push(ITokenDescriptor.Coordinate({x:21, y:9}));
        coordinates.push(ITokenDescriptor.Coordinate({x:5, y:6}));
        coordinates.push(ITokenDescriptor.Coordinate({x:11, y:17}));
        coordinates.push(ITokenDescriptor.Coordinate({x:4, y:23}));
        coordinates.push(ITokenDescriptor.Coordinate({x:18, y:6}));
        coordinates.push(ITokenDescriptor.Coordinate({x:9, y:7}));
        coordinates.push(ITokenDescriptor.Coordinate({x:4, y:15}));
        coordinates.push(ITokenDescriptor.Coordinate({x:2, y:22}));
        coordinates.push(ITokenDescriptor.Coordinate({x:23, y:4}));
        coordinates.push(ITokenDescriptor.Coordinate({x:2, y:10}));
        coordinates.push(ITokenDescriptor.Coordinate({x:1, y:21}));
        coordinates.push(ITokenDescriptor.Coordinate({x:14, y:23}));
        coordinates.push(ITokenDescriptor.Coordinate({x:19, y:1}));
        coordinates.push(ITokenDescriptor.Coordinate({x:19, y:14}));
        coordinates.push(ITokenDescriptor.Coordinate({x:18, y:18}));
        coordinates.push(ITokenDescriptor.Coordinate({x:11, y:24}));
        coordinates.push(ITokenDescriptor.Coordinate({x:9, y:24}));
        coordinates.push(ITokenDescriptor.Coordinate({x:10, y:5}));
        coordinates.push(ITokenDescriptor.Coordinate({x:1, y:8}));
        coordinates.push(ITokenDescriptor.Coordinate({x:11, y:18}));
        coordinates.push(ITokenDescriptor.Coordinate({x:2, y:8}));
        coordinates.push(ITokenDescriptor.Coordinate({x:14, y:16}));
        coordinates.push(ITokenDescriptor.Coordinate({x:14, y:4}));
        coordinates.push(ITokenDescriptor.Coordinate({x:18, y:14}));
        coordinates.push(ITokenDescriptor.Coordinate({x:20, y:24}));
        coordinates.push(ITokenDescriptor.Coordinate({x:15, y:0}));
        coordinates.push(ITokenDescriptor.Coordinate({x:9, y:0}));
        coordinates.push(ITokenDescriptor.Coordinate({x:20, y:17}));
        coordinates.push(ITokenDescriptor.Coordinate({x:9, y:3}));
        coordinates.push(ITokenDescriptor.Coordinate({x:15, y:4}));
        coordinates.push(ITokenDescriptor.Coordinate({x:23, y:20}));
        coordinates.push(ITokenDescriptor.Coordinate({x:12, y:1}));
        coordinates.push(ITokenDescriptor.Coordinate({x:23, y:6}));
        coordinates.push(ITokenDescriptor.Coordinate({x:1, y:20}));
        coordinates.push(ITokenDescriptor.Coordinate({x:1, y:17}));
        coordinates.push(ITokenDescriptor.Coordinate({x:20, y:5}));
        coordinates.push(ITokenDescriptor.Coordinate({x:7, y:24}));
        coordinates.push(ITokenDescriptor.Coordinate({x:23, y:13}));
        coordinates.push(ITokenDescriptor.Coordinate({x:13, y:22}));
        coordinates.push(ITokenDescriptor.Coordinate({x:15, y:3}));
        coordinates.push(ITokenDescriptor.Coordinate({x:20, y:7}));
        coordinates.push(ITokenDescriptor.Coordinate({x:11, y:2}));
        coordinates.push(ITokenDescriptor.Coordinate({x:4, y:18}));
        coordinates.push(ITokenDescriptor.Coordinate({x:3, y:0}));
        coordinates.push(ITokenDescriptor.Coordinate({x:8, y:3}));
        coordinates.push(ITokenDescriptor.Coordinate({x:5, y:0}));
        coordinates.push(ITokenDescriptor.Coordinate({x:11, y:22}));
        coordinates.push(ITokenDescriptor.Coordinate({x:10, y:4}));
        coordinates.push(ITokenDescriptor.Coordinate({x:19, y:23}));
        coordinates.push(ITokenDescriptor.Coordinate({x:2, y:23}));
        coordinates.push(ITokenDescriptor.Coordinate({x:13, y:19}));
        coordinates.push(ITokenDescriptor.Coordinate({x:4, y:22}));
        coordinates.push(ITokenDescriptor.Coordinate({x:6, y:19}));
        coordinates.push(ITokenDescriptor.Coordinate({x:5, y:13}));
        coordinates.push(ITokenDescriptor.Coordinate({x:22, y:19}));
        coordinates.push(ITokenDescriptor.Coordinate({x:7, y:20}));
        coordinates.push(ITokenDescriptor.Coordinate({x:15, y:19}));
        coordinates.push(ITokenDescriptor.Coordinate({x:9, y:19}));
        coordinates.push(ITokenDescriptor.Coordinate({x:3, y:4}));
        coordinates.push(ITokenDescriptor.Coordinate({x:10, y:2}));
        coordinates.push(ITokenDescriptor.Coordinate({x:5, y:21}));
        coordinates.push(ITokenDescriptor.Coordinate({x:15, y:6}));
        coordinates.push(ITokenDescriptor.Coordinate({x:5, y:2}));
        coordinates.push(ITokenDescriptor.Coordinate({x:9, y:11}));
        coordinates.push(ITokenDescriptor.Coordinate({x:19, y:5}));
        coordinates.push(ITokenDescriptor.Coordinate({x:13, y:7}));
        coordinates.push(ITokenDescriptor.Coordinate({x:12, y:6}));
        coordinates.push(ITokenDescriptor.Coordinate({x:2, y:5}));
        coordinates.push(ITokenDescriptor.Coordinate({x:3, y:13}));
        coordinates.push(ITokenDescriptor.Coordinate({x:23, y:21}));
        coordinates.push(ITokenDescriptor.Coordinate({x:9, y:21}));
        coordinates.push(ITokenDescriptor.Coordinate({x:2, y:6}));
        coordinates.push(ITokenDescriptor.Coordinate({x:11, y:19}));
        coordinates.push(ITokenDescriptor.Coordinate({x:15, y:22}));
        coordinates.push(ITokenDescriptor.Coordinate({x:22, y:22}));
        coordinates.push(ITokenDescriptor.Coordinate({x:11, y:16}));
        coordinates.push(ITokenDescriptor.Coordinate({x:23, y:0}));
        coordinates.push(ITokenDescriptor.Coordinate({x:5, y:4}));
        coordinates.push(ITokenDescriptor.Coordinate({x:9, y:13}));
        coordinates.push(ITokenDescriptor.Coordinate({x:5, y:17}));
        coordinates.push(ITokenDescriptor.Coordinate({x:17, y:9}));
        coordinates.push(ITokenDescriptor.Coordinate({x:11, y:1}));
        coordinates.push(ITokenDescriptor.Coordinate({x:4, y:1}));
        coordinates.push(ITokenDescriptor.Coordinate({x:16, y:10}));
        coordinates.push(ITokenDescriptor.Coordinate({x:12, y:2}));
        coordinates.push(ITokenDescriptor.Coordinate({x:17, y:6}));
        coordinates.push(ITokenDescriptor.Coordinate({x:21, y:5}));
        coordinates.push(ITokenDescriptor.Coordinate({x:16, y:1}));
        coordinates.push(ITokenDescriptor.Coordinate({x:17, y:23}));
        coordinates.push(ITokenDescriptor.Coordinate({x:9, y:15}));
        coordinates.push(ITokenDescriptor.Coordinate({x:7, y:0}));
        coordinates.push(ITokenDescriptor.Coordinate({x:18, y:22}));
        coordinates.push(ITokenDescriptor.Coordinate({x:5, y:11}));
        coordinates.push(ITokenDescriptor.Coordinate({x:3, y:2}));
        coordinates.push(ITokenDescriptor.Coordinate({x:23, y:14}));
        coordinates.push(ITokenDescriptor.Coordinate({x:17, y:1}));
        coordinates.push(ITokenDescriptor.Coordinate({x:11, y:23}));
        coordinates.push(ITokenDescriptor.Coordinate({x:13, y:14}));
        coordinates.push(ITokenDescriptor.Coordinate({x:19, y:22}));
        coordinates.push(ITokenDescriptor.Coordinate({x:11, y:11}));
        coordinates.push(ITokenDescriptor.Coordinate({x:18, y:17}));
        coordinates.push(ITokenDescriptor.Coordinate({x:18, y:15}));
        coordinates.push(ITokenDescriptor.Coordinate({x:6, y:16}));
        coordinates.push(ITokenDescriptor.Coordinate({x:16, y:7}));
        coordinates.push(ITokenDescriptor.Coordinate({x:22, y:16}));
        coordinates.push(ITokenDescriptor.Coordinate({x:19, y:13}));
        coordinates.push(ITokenDescriptor.Coordinate({x:7, y:23}));
        coordinates.push(ITokenDescriptor.Coordinate({x:10, y:7}));
        coordinates.push(ITokenDescriptor.Coordinate({x:1, y:24}));
        coordinates.push(ITokenDescriptor.Coordinate({x:11, y:4}));
        coordinates.push(ITokenDescriptor.Coordinate({x:20, y:21}));
        coordinates.push(ITokenDescriptor.Coordinate({x:3, y:21}));
        coordinates.push(ITokenDescriptor.Coordinate({x:20, y:18}));
        coordinates.push(ITokenDescriptor.Coordinate({x:16, y:13}));
        coordinates.push(ITokenDescriptor.Coordinate({x:7, y:11}));
        coordinates.push(ITokenDescriptor.Coordinate({x:1, y:2}));
        coordinates.push(ITokenDescriptor.Coordinate({x:7, y:21}));
        coordinates.push(ITokenDescriptor.Coordinate({x:14, y:18}));
        coordinates.push(ITokenDescriptor.Coordinate({x:20, y:9}));
        coordinates.push(ITokenDescriptor.Coordinate({x:8, y:16}));
        coordinates.push(ITokenDescriptor.Coordinate({x:1, y:9}));
        coordinates.push(ITokenDescriptor.Coordinate({x:8, y:13}));
        coordinates.push(ITokenDescriptor.Coordinate({x:17, y:21}));
        coordinates.push(ITokenDescriptor.Coordinate({x:1, y:18}));
        coordinates.push(ITokenDescriptor.Coordinate({x:6, y:0}));
        coordinates.push(ITokenDescriptor.Coordinate({x:21, y:21}));
        coordinates.push(ITokenDescriptor.Coordinate({x:2, y:14}));
        coordinates.push(ITokenDescriptor.Coordinate({x:14, y:3}));
        coordinates.push(ITokenDescriptor.Coordinate({x:14, y:22}));
        coordinates.push(ITokenDescriptor.Coordinate({x:21, y:1}));
        coordinates.push(ITokenDescriptor.Coordinate({x:9, y:22}));
        coordinates.push(ITokenDescriptor.Coordinate({x:23, y:1}));
        coordinates.push(ITokenDescriptor.Coordinate({x:8, y:1}));
        coordinates.push(ITokenDescriptor.Coordinate({x:15, y:18}));
        coordinates.push(ITokenDescriptor.Coordinate({x:2, y:4}));
        coordinates.push(ITokenDescriptor.Coordinate({x:1, y:5}));
        coordinates.push(ITokenDescriptor.Coordinate({x:9, y:18}));
        coordinates.push(ITokenDescriptor.Coordinate({x:10, y:17}));
        coordinates.push(ITokenDescriptor.Coordinate({x:17, y:19}));
        coordinates.push(ITokenDescriptor.Coordinate({x:15, y:11}));
        coordinates.push(ITokenDescriptor.Coordinate({x:14, y:10}));
        coordinates.push(ITokenDescriptor.Coordinate({x:4, y:10}));
        coordinates.push(ITokenDescriptor.Coordinate({x:15, y:7}));
        coordinates.push(ITokenDescriptor.Coordinate({x:6, y:15}));
        coordinates.push(ITokenDescriptor.Coordinate({x:16, y:15}));
        coordinates.push(ITokenDescriptor.Coordinate({x:11, y:15}));
        coordinates.push(ITokenDescriptor.Coordinate({x:23, y:8}));
        coordinates.push(ITokenDescriptor.Coordinate({x:13, y:0}));
        coordinates.push(ITokenDescriptor.Coordinate({x:20, y:11}));
        coordinates.push(ITokenDescriptor.Coordinate({x:10, y:14}));
        coordinates.push(ITokenDescriptor.Coordinate({x:9, y:1}));
        coordinates.push(ITokenDescriptor.Coordinate({x:20, y:0}));
        coordinates.push(ITokenDescriptor.Coordinate({x:5, y:5}));
        coordinates.push(ITokenDescriptor.Coordinate({x:22, y:6}));
        coordinates.push(ITokenDescriptor.Coordinate({x:4, y:2}));
        coordinates.push(ITokenDescriptor.Coordinate({x:4, y:20}));
        coordinates.push(ITokenDescriptor.Coordinate({x:20, y:3}));
        coordinates.push(ITokenDescriptor.Coordinate({x:23, y:24}));
        coordinates.push(ITokenDescriptor.Coordinate({x:6, y:22}));
        coordinates.push(ITokenDescriptor.Coordinate({x:21, y:18}));
        coordinates.push(ITokenDescriptor.Coordinate({x:21, y:3}));
        coordinates.push(ITokenDescriptor.Coordinate({x:17, y:24}));
        coordinates.push(ITokenDescriptor.Coordinate({x:21, y:19}));
        coordinates.push(ITokenDescriptor.Coordinate({x:11, y:20}));
        coordinates.push(ITokenDescriptor.Coordinate({x:18, y:13}));
        coordinates.push(ITokenDescriptor.Coordinate({x:17, y:10}));
        coordinates.push(ITokenDescriptor.Coordinate({x:6, y:14}));
        coordinates.push(ITokenDescriptor.Coordinate({x:18, y:16}));
        coordinates.push(ITokenDescriptor.Coordinate({x:18, y:1}));
        coordinates.push(ITokenDescriptor.Coordinate({x:13, y:9}));
        coordinates.push(ITokenDescriptor.Coordinate({x:16, y:18}));
        coordinates.push(ITokenDescriptor.Coordinate({x:8, y:6}));
        coordinates.push(ITokenDescriptor.Coordinate({x:22, y:10}));
        coordinates.push(ITokenDescriptor.Coordinate({x:18, y:7}));
        coordinates.push(ITokenDescriptor.Coordinate({x:8, y:17}));
        coordinates.push(ITokenDescriptor.Coordinate({x:13, y:11}));
        coordinates.push(ITokenDescriptor.Coordinate({x:6, y:24}));
        coordinates.push(ITokenDescriptor.Coordinate({x:7, y:2}));
        coordinates.push(ITokenDescriptor.Coordinate({x:16, y:22}));

        return coordinates;
    }
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