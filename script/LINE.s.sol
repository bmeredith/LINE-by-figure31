// SPDX-License-Identifier: MIT
pragma solidity =0.8.23;

import {Descriptor} from '../src/Descriptor.sol';
import {LINE} from '../src/LINE.sol';
import {Script} from 'forge-std/Script.sol';

abstract contract Deploy is Script {
  function _deploy() internal {
    vm.startBroadcast();
    Descriptor descriptor = new Descriptor();
    new LINE(address(descriptor));
    vm.stopBroadcast();
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