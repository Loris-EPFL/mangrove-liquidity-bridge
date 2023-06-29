// SPDX-License-Identifier:	AGPL-3.0
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
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
        console2.log("profile:", profile);

        if (areEquals(profile, "maticmum")) {
            fork = new MumbaiFork();
        } else if (areEquals(profile, "polygon")) {
            fork = new PolygonFork();
        } else {
            revert("Unknown profile");
        }
    }
}
