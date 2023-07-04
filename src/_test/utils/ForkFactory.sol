// SPDX-License-Identifier:	AGPL-3.0
pragma solidity >=0.8.10;

import {Vm} from "forge-std/Vm.sol";
import {GenericFork} from "mgv_test/lib/forks/Generic.sol";
import {PolygonFork} from "mgv_test/lib/forks/Polygon.sol";
import {MumbaiFork} from "mgv_test/lib/forks/Mumbai.sol";

library ForkFactory {
    function areEquals(
        string memory str1,
        string memory str2
    ) public pure returns (bool) {
        return
            keccak256(abi.encodePacked(str1)) ==
            keccak256(abi.encodePacked(str2));
    }

    function getFork(Vm vm) public returns (GenericFork fork) {
        string memory profile = vm.envString("FOUNDRY_PROFILE");

        if (areEquals(profile, "mumbai")) {
            fork = new MumbaiFork();
            require(fork.CHAIN_ID() == 80001, "Invalid chain id");
        } else if (areEquals(profile, "polygon")) {
            fork = new PolygonFork();
            require(fork.CHAIN_ID() == 1101, "Invalid chain id");
        } else {
            revert("Unknown profile");
        }
    }
}
