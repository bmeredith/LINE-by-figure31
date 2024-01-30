// SPDX-License-Identifier: MIT
pragma solidity =0.8.23;

import {ITokenDescriptor} from "../src/ITokenDescriptor.sol";
import {Descriptor} from '../src/Descriptor.sol';
import {LINE} from '../src/LINE.sol';
import {Script} from 'forge-std/Script.sol';

abstract contract Deploy is Script {
  function _deploy() internal {
    vm.startBroadcast();
    Descriptor descriptor = new Descriptor();
    LINE line = new LINE(address(descriptor));

    line.setInitialAvailableCoordinates(_getMintableCoordinates());
    vm.stopBroadcast();
  }

  function _getMintableCoordinates() private pure returns (ITokenDescriptor.Coordinate[] memory) {
    ITokenDescriptor.Coordinate[] memory coordinates = new ITokenDescriptor.Coordinate[](20);
    for(uint256 i=0;i < 10;i++) {
        coordinates[i] = (ITokenDescriptor.Coordinate({x: i+1, y: 1}));
    }

    for(uint256 i=0;i < 10;i++) {
        coordinates[i+10] = (ITokenDescriptor.Coordinate({x: i+1, y: 24}));
    }

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